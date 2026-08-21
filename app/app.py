from datetime import datetime
import uuid
import boto3
from botocore.exceptions import ClientError
from werkzeug.utils import secure_filename
from flask import Flask, render_template, request, redirect, url_for, flash
import logging
import os

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'dev-secret-key')
app.config['MAX_CONTENT_LENGTH'] = 5 * 1024 * 1024  # 5 MB upload limit

# logging — stdout, so `kubectl logs` sees it (no PV/filebeat sidecar in the k8s deploy)
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(message)s', datefmt='%d.%m.%y %H:%M')

# AWS resources
AWS_REGION = os.environ.get('AWS_REGION', 'eu-north-1')
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE', 'noteapp-notes')
S3_BUCKET = os.environ.get('S3_BUCKET_NAME', 'noteapp-images-686062433938-eu-north-1')

dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
table = dynamodb.Table(DYNAMODB_TABLE)
# Pin the regional endpoint explicitly: boto3's default S3 endpoint resolution can hand back
# the global s3.amazonaws.com host, whose redirect to the real regional host invalidates the
# SigV4 signature on presigned URLs (Host is a signed header).
s3 = boto3.client('s3', region_name=AWS_REGION, endpoint_url=f'https://s3.{AWS_REGION}.amazonaws.com')

ALLOWED_IMAGE_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}
NOTE_COLORS = {'default', 'red', 'orange', 'yellow', 'green', 'blue', 'purple'}


def allowed_image(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_IMAGE_EXTENSIONS


def upload_image(file_storage):
    extension = file_storage.filename.rsplit('.', 1)[1].lower()
    key = f"notes/{uuid.uuid4().hex}.{extension}"
    s3.upload_fileobj(
        file_storage.stream,
        S3_BUCKET,
        key,
        ExtraArgs={'ContentType': file_storage.content_type}
    )
    return key


def delete_image(image_key):
    if image_key:
        s3.delete_object(Bucket=S3_BUCKET, Key=image_key)


def get_image_url(image_key):
    if not image_key:
        return None
    return s3.generate_presigned_url(
        'get_object',
        Params={'Bucket': S3_BUCKET, 'Key': image_key},
        ExpiresIn=3600
    )


# list of existing notes
def get_existing_notes():
    notes = []
    response = table.scan()

    for note in response.get('Items', []):
        created_at = note.get('created_at')
        try:
            created_at = datetime.fromisoformat(created_at)
        except (TypeError, ValueError):
            created_at = 'N/A'

        notes.append({
            'title': note['title'],
            'content': note['content'],
            'created_at': created_at,
            '_id': note['id'],
            'image_url': get_image_url(note.get('image_key')),
            'color': note.get('color', 'default'),
        })

    notes.sort(key=lambda n: n['created_at'] if n['created_at'] != 'N/A' else datetime.min, reverse=True)
    return notes


# main page
@app.route('/')
@app.route('/main')
def main():
    notes = get_existing_notes()
    return render_template('main.html', notes=notes)


# create route+fun
@app.route('/create', methods=['GET', 'POST'])
def create():
    if request.method == 'POST':
        title = request.form['title']
        content = request.form['content']
        image_file = request.files.get('image')

        if not title:
            flash('please give a title to your note', 'error')
        elif image_file and image_file.filename and not allowed_image(image_file.filename):
            flash('Only PNG, JPG, GIF, or WEBP images are allowed', 'error')
        else:
            note_id = uuid.uuid4().hex
            current_time = datetime.now()
            color = request.form.get('color', 'default')
            if color not in NOTE_COLORS:
                color = 'default'

            image_key = None
            if image_file and image_file.filename:
                image_key = upload_image(image_file)

            note_data = {
                'id': note_id,
                'title': title,
                'content': content,
                'created_at': current_time.isoformat(),
                'color': color,
            }
            if image_key:
                note_data['image_key'] = image_key

            table.put_item(Item=note_data)

            logging.info(f'note "{title}" was created with unique number {note_id}')

            return redirect(url_for('main'), code=302)
    return render_template('create.html')


# read route+fun
@app.route('/read/<id>')
def read(id):
    try:
        note = table.get_item(Key={'id': id}).get('Item')

        return render_template(
            'read.html',
            title=note['title'],
            content=note['content'],
            image_url=get_image_url(note.get('image_key')),
            color=note.get('color', 'default')
        )
    except Exception as e:
        logging.error(f'Note "{id}"not found : {e}')
        return internal_server_error('Internal server error occurred while find the note.')


# update route+fun
@app.route('/update/<id>', methods=['GET', 'POST'])
def update(id):
    try:
        note = table.get_item(Key={'id': id}).get('Item')

        if not note:
            # Handle case where the note is not found
            return page_not_found("Note not found")

        if request.method == 'POST':
            new_content = request.form['content']
            image_file = request.files.get('image')

            update_expression = 'SET #content = :content'
            expression_names = {'#content': 'content'}
            expression_values = {':content': new_content}

            if image_file and image_file.filename:
                if not allowed_image(image_file.filename):
                    flash('Only PNG, JPG, GIF, or WEBP images are allowed', 'error')
                    return render_template(
                        'update.html',
                        title=note['title'],
                        content=note['content'],
                        image_url=get_image_url(note.get('image_key'))
                    )
                delete_image(note.get('image_key'))
                new_image_key = upload_image(image_file)
                update_expression += ', #image_key = :image_key'
                expression_names['#image_key'] = 'image_key'
                expression_values[':image_key'] = new_image_key

            table.update_item(
                Key={'id': id},
                UpdateExpression=update_expression,
                ExpressionAttributeNames=expression_names,
                ExpressionAttributeValues=expression_values
            )
            logging.info(f'Changes saved to note "{id}"')
            return redirect(url_for('main'))

        return render_template(
            'update.html',
            title=note['title'],
            content=note['content'],
            image_url=get_image_url(note.get('image_key'))
        )
    except Exception as e:
        logging.error(f'Error occurred while updating note "{id}": {e}')
        return internal_server_error('Internal server error occurred while updating the note.')


# delete route+fun
@app.route('/delete/<id>', methods=['GET', 'POST'])
def delete(id):
    if request.method == 'POST':
        try:
            note = table.get_item(Key={'id': id}).get('Item')
            table.delete_item(Key={'id': id})
            if note:
                delete_image(note.get('image_key'))
                logging.info(f'Note "{id}" was deleted from the database')
            else:
                logging.warning(f'Note "{id}" not found in the database')
            return redirect(url_for('main'))
        except ClientError as e:
            logging.error(f'Error occurred while deleting note "{id}": {e}')
            return page_not_found("Note not found")
    elif request.method == 'GET':
        result = table.get_item(Key={'id': id}).get('Item')
        return render_template('delete.html', title=result['title'])


# errors
@app.errorhandler(404)
def page_not_found(error):
    return render_template('error.html', error_message=error), 404


@app.errorhandler(500)
def internal_server_error(error):
    return render_template('error.html', error_message='Internal server error'), 500


@app.errorhandler(413)
def file_too_large(error):
    return render_template('error.html', error_message='Uploaded image is too large (max 5 MB)'), 413


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8000))
    app.run(host='0.0.0.0', port=port, debug=True)
