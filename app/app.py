from flask import Flask, render_template, request, redirect, url_for, flash
import logging
import os

app = Flask(__name__)

# logging?
log_file = 'logs/my_notes_app.log'
logging.basicConfig(filename=log_file, level=logging.INFO,
                    format='%(asctime)s - %(message)s', datefmt='%d.%m.%y %H:%M')


# list of existing notes
def get_existing_notes():
    notes = []
    for filename in os.listdir('notes'):
        if filename.endswith('.txt'):
            with open(os.path.join('notes', filename), 'r') as file:
                title = filename[:-4]
                content = file.read()
                notes.append({'title': title, 'content': content})
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
        if not title:
            flash('please give a title to your note', 'error')
        else:
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
@app.route('/delete/<title>', methods=['GET', 'POST'])
def delete(title):
    if request.method == 'POST':
        try:
            os.remove(f'notes/{title}.txt')
            logging.info(f'note "{title}" was deleted')
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
