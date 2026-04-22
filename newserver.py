from pymongo import MongoClient


def run():
    client = MongoClient(
        "mongodb://admin2:asd64026@54.116.116.54:27017/?authSource=admin"
    )

    db = client.test
    db.testcollection.insert_one({"test": 1234})

    test_data = list(db.testcollection.find({}))
    # print(test_data)


if __name__ == "__main__":
    run()
