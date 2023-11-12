import unittest
import requests
from datetime import datetime
from bson.objectid import ObjectId
from bs4 import BeautifulSoup
import time

class TestMyFlaskApp(unittest.TestCase):
    def setUp(self):
        self.base_url = 'http://localhost:5000'
        self.creation_time = None

    def test_app_is_up(self):
        response = requests.get(self.base_url)
        self.assertEqual(response.status_code, 200)

    def test_crud_funs(self):
        create_url = f"{self.base_url}/create"
        create_data = {'title': 'try1', 'content': 'try note'}
        response = requests.post(create_url, data=create_data)
        self.assertEqual(response.status_code, 200)

        self.creation_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        time.sleep(1)

        response_main = requests.get(f"{self.base_url}/main")
        soup = BeautifulSoup(response_main.content, 'html.parser')
        note_elements = soup.find_all('div', {'class': 'card'})

        note_id = None
        for note_element in note_elements:
            note_title = note_element.find('h5', {'class': 'card-title'}).text.strip()
            created_at = note_element.find('p', {'class': 'card-text'}, string='Created At:')
            if created_at and note_title == 'try1':
                note_id = note_element.find('p', {'class': 'card-text'}, string='ID:').text.split(':')[-1].strip()
                self.assertTrue(ObjectId.is_valid(note_id))
                break

        if note_id is not None:
            view_url = f"{self.base_url}/read/{note_id}"
            response = requests.get(view_url)
            self.assertEqual(response.status_code, 200)

            update_url = f"{self.base_url}/update/{note_id}"
            update_data = {'content': 'updated the note'}
            response = requests.post(update_url, data=update_data)
            self.assertEqual(response.status_code, 302)

            delete_url = f"{self.base_url}/delete/{note_id}"
            response = requests.post(delete_url)
            self.assertEqual(response.status_code, 302)
        else:
            print(f"error with matching time of creation or something")

    def test_error_pages(self):
        response = requests.get(f"{self.base_url}/aaa")
        self.assertEqual(response.status_code, 404)
        response = requests.get(f"{self.base_url}/read/aaa")
        self.assertEqual(response.status_code, 500)

if __name__ == '__main__':
    unittest.main()


