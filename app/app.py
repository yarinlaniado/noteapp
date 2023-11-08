from datetime import datetime
from bson.objectid import ObjectId
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
    cursor = collection.find({})  # Exclude _id field from the query result

    for note in cursor:
        notes.append({
            'title': note['title'],
            'content': note['content'],
            'created_at': note.get('created_at', 'N/A'),  # Use get method to handle missing 'created_at' attribute
            '_id': note['_id']
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
    print(notes)
    return render_template('main.html', notes=notes)


# create route+fun
from pymongo import ReturnDocument

# create route+fun
'''def get_unique_number():
    # Find and modify the counter document to increment the counter by 1
    counter_doc = counters_collection.find_one_and_update(
        {'_id': 'unique_number'},
        {'$inc': {'value': 1}},
        upsert=True,  # Create the document if it doesn't exist
        return_document=ReturnDocument.AFTER  # Return the modified document
    )
    return counter_doc['value']
    '''


@app.route('/create', methods=['GET', 'POST'])
def create():
    if request.method == 'POST':
        title = request.form['title']
        content = request.form['content']
        if not title:
            flash('please give a title to your note', 'error')
        else:
            # Generate a unique number (you can use MongoDB's auto-increment feature or another method)
              # Implement a function to generate a unique number

            # Append the unique number to the note title or content
            unique_title = f"{title}"
            unique_content = f"{content}"
            # Get the current date and time
            current_time = datetime.now()


            # Create a dictionary with note data including title, content, current time, and unique number
            note_data = {
                'title': unique_title,
                'content': unique_content,
                'created_at': current_time,
            }

            # Insert the note data into the MongoDB collection
            inserted_note = collection.insert_one(note_data)

            #with open(f'notes/{unique_title}.txt', 'w') as file:

             #   file.write(unique_content)
            logging.info(f'note "{unique_title}" was created with unique number { inserted_note.inserted_id }')

            # Redirect to the main page or display a success message
            return redirect("/", code=302)
    return render_template('create.html')



# read route+fun
@app.route('/read/<id>')
def read(id):
    try:
        note = collection.find_one({"_id":ObjectId(id) })

        return render_template('read.html', title=note['title'], content=note['content'])
    except Exception as e:
        logging.error(f'Note "{id}"not found : {e}')
        return internal_server_error('Internal server error occurred while find the note.')


# update route+fun
# update route+fun
@app.route('/update/<id>', methods=['GET', 'POST'])
def update(id):
    try:

        # Find the note by title in the MongoDB collection
        note = collection.find_one({"_id":ObjectId(id) })

        if not note:
            # Handle case where the note is not found
            return page_not_found("Note not found")

        if request.method == 'POST':
            # Update the note's content in the MongoDB collection
            new_content = request.form['content']
            collection.update_one({"_id":ObjectId(id)}, {'$set': {'content': new_content}})
            logging.info(f'Changes saved to note "{id}"')
            return redirect(url_for('main'))

        return render_template('update.html',title= note['title'], content=note['content'])
    except Exception as e:
        logging.error(f'Error occurred while updating note "{id}": {e}')
        return internal_server_error('Internal server error occurred while updating the note.')



# delete route+fun
@app.route('/delete/<id>', methods=['GET','POST'])
def delete(id):
    if request.method == 'POST':
        try:
            #os.remove(f'notes/{title}.txt')
            # Delete the note from the MongoDB collection using the title as a filter
            result = collection.delete_one({"_id": ObjectId(id)})
            if result.deleted_count == 1:
                logging.info(f'Note "{id}" was deleted from the database')
            else:
                logging.warning(f'Note "{id}" not found in the database')
            return redirect(url_for('main'))
        except FileNotFoundError:
            return page_not_found("Note not found")
    elif request.method == 'GET':
      result = collection.find_one({"_id": ObjectId(id)})
      return render_template('delete.html', title=result['title'])


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
