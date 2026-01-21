import pytest
from src.app import create_app
from src.models.person import Person, PersonSchema


@pytest.fixture
def app():
    app = create_app('testing')
    app.config['TESTING'] = True
    return app


@pytest.fixture
def client(app):
    return app.test_client()


def test_index(client):
    response = client.get('/')
    assert response.status_code == 200
    assert b'Welcome to the Titanic API' in response.data


def test_get_people_empty(client):
    response = client.get('/people')
    assert response.status_code == 200
    assert response.get_json() == []


def test_person_schema():
    schema = PersonSchema()
    data = {
        'survived': 1,
        'passengerClass': 1,
        'name': 'Test Person',
        'sex': 'male',
        'age': 25.0,
        'siblingsOrSpousesAboard': 0,
        'parentsOrChildrenAboard': 0,
        'fare': 10.0
    }
    result = schema.dump(data)
    assert result['survived'] == 1
    assert result['name'] == 'Test Person'


def test_person_model():
    data = {
        'survived': 1,
        'passengerClass': 1,
        'name': 'Test Person',
        'sex': 'male',
        'age': 25.0,
        'siblingsOrSpousesAboard': 0,
        'parentsOrChildrenAboard': 0,
        'fare': 10.0
    }
    person = Person(data)
    assert person.survived == 1
    assert person.name == 'Test Person'
    assert person.age == 25.0