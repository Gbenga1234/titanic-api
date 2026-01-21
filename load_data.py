import csv
import os
from src.app import create_app
from src.models.person import Person

def load_data():
    app = create_app('development')
    with app.app_context():
        # Check if data already exists
        if Person.query.count() > 0:
            print("Data already loaded")
            return

        with open('titanic.csv', 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                data = {
                    'survived': int(row['Survived']),
                    'passengerClass': int(row['Pclass']),
                    'name': row['Name'],
                    'sex': row['Sex'],
                    'age': float(row['Age']) if row['Age'] else None,
                    'siblingsOrSpousesAboard': int(row['Siblings/Spouses Aboard']),
                    'parentsOrChildrenAboard': int(row['Parents/Children Aboard']),
                    'fare': float(row['Fare'])
                }
                person = Person(data)
                person.save()
        print("Data loaded successfully")

if __name__ == '__main__':
    load_data()