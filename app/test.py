import unittest
import requests
from bs4 import BeautifulSoup
#import time

class TestMyFlaskApp(unittest.TestCase):
    def setUp(self):
        self.base_url = 'http://localhost:8080'
        self.creation_time = None

    def test_app_is_up(self):
        response = requests.get(self.base_url)
        self.assertEqual(response.status_code, 200)

    def test_crud_funs(self):
        create_url = f"{self.base_url}/create"
        create_data = {'title': 'try1', 'content': 'try note'}
        response = requests.post(create_url, data=create_data)
        self.assertEqual(response.status_code, 200)
        #time.sleep(3)

        soup = BeautifulSoup(response.content, 'html.parser')
        note_title = 'try1'
        note_element = soup.find('h5', {'class': 'card-title'}, text=note_title).parent

        view_url = note_element.find('a', {'class': 'btn-secondary'})['href']
        edit_url = note_element.find('a', {'class': 'btn-warning'})['href']
        delete_url = note_element.find('a', {'class': 'btn-danger'})['href']

        response = requests.get(self.base_url + view_url)
        self.assertEqual(response.status_code, 200)

        response = requests.get(self.base_url + edit_url)
        self.assertEqual(response.status_code, 200)
        update_data = {'content': 'updated the note'}
        response = requests.post(self.base_url + edit_url, data=update_data)
        self.assertEqual(response.status_code, 200)
        #time.sleep(3)


        response = requests.post(self.base_url + delete_url)
        self.assertEqual(response.status_code, 200)

    def test_error_pages(self):
        response = requests.get(f"{self.base_url}/aaa")
        self.assertEqual(response.status_code, 404)
        response = requests.get(f"{self.base_url}/read/aaa")
        self.assertEqual(response.status_code, 500)

if __name__ == '__main__':
    unittest.main()




