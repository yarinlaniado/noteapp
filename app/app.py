from datetime import datetime
from pymongo import MongoClient
from flask import Flask, render_template, request, redirect, url_for, flash
import logging
import os

app = Flask(__name__)

# logging
log_file = 'logs/my_notes_app.log'
logging.basicConfig(filename=log_file, level=logging.INFO,
                    format='%(asctime)s - %(message)s', datefmt='%d.%m.%y %H:%M')


# list of existing notes
def get_existing_notes():
    notes = []
    cursor = collection.find({}, {'_id': 0})  # Exclude _id field from the query result
    for note in cursor:
        notes.append({
            'title': note['title'],
            'content': note['content'],
            'created_at': note.get('created_at', 'N/A')  # Use get method to handle missing 'created_at' attribute
        })
    return notes


# MongoDB connection
client = MongoClient('mongodb://note:note@localhost:27017/')
db = client['notes_db']
collection = db['notes_collection']

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
        if not title:
            flash('please give a title to your note', 'error')
        else:
            # Get the current date and time
            current_time = datetime.now()

            # Create a dictionary with note data including title, content, and current time
            note_data = {
                'title': title,
                'content': content,
                'created_at': current_time
            }

            # Insert the note data into the MongoDB collection
            collection.insert_one(note_data)

            with open(f'notes/{title}.txt', 'w') as file:
                file.write(content)
            logging.info(f'note "{title}" was created')
            return redirect("/", code=302)
    return render_template('create.html')


# read route+fun
@app.route('/read/<title>')
def read(title):
    try:
        with open(f'notes/{title}.txt', 'r') as file:
            content = file.read()
        return render_template('read.html', title=title, content=content)
    except FileNotFoundError:
        return page_not_found("Note not found")


# update route+fun
@app.route('/update/<title>', methods=['GET', 'POST'])
def update(title):
    try:
        with open(f'notes/{title}.txt', 'r') as file:
            content = file.read()
        if request.method == 'POST':
            new_content = request.form['content']
            with open(f'notes/{title}.txt', 'w') as file:
                file.write(new_content)
            logging.info(f'changes saved to "{title}"')
            return redirect(url_for('main'))
        return render_template('update.html', title=title, content=content)
    except FileNotFoundError:
        return page_not_found("Note not found")


# delete route+fun
@app.route('/delete/<title>', methods=['GET','POST'])
def delete(title):
    if request.method == 'POST':

        try:
            os.remove(f'notes/{title}.txt')
            # Delete the note from the MongoDB collection using the title as a filter
            result = collection.delete_one({'title': title})
            if result.deleted_count == 1:
                logging.info(f'Note "{title}" was deleted from the database')
            else:
                logging.warning(f'Note "{title}" not found in the database')
            return redirect(url_for('main'))
        except FileNotFoundError:
            return page_not_found("Note not found")
    return render_template('delete.html', title=title)


# errors
@app.errorhandler(404)
def page_not_found(error):
    return render_template('error.html', error_message=error), 404


@app.errorhandler(500)
def internal_server_error(error):
    return render_template('error.html', error_message='Internal server error'), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
