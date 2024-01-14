from pymongo import MongoClient

def run():
    client = MongoClient('mongodb://zxc0214:asd64026@3.35.4.52', 27017)

    db = client.test
    db.testcollection.insert_one({'test': 1234}) 

    test_data = list(db.testcollection.find({}))
    print(test_data)

if __name__ == "__main__":
    run()