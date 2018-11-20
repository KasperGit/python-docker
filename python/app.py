from flask import Flask, request
from flask_restplus import Api, Resource, fields

app = Flask(__name__)
api = Api(app, version='0.0.0.0.1', title='Varnish test APP api', description='Test APP API voor Varnish by Kasper van Dijk')

import time


if __name__ == '__main__':
    app.run(debug=True)


@api.route('/hello')
class HelloWorld(Resource):
    def get(self):
        return {'Hallo': 'Dit is het programma APP'}

@api.route('/sleep')
class Sleep(Resource):
    def get(self):
        (time.sleep(1)) 
	return {'APP':'heeft wat vertraging'}

if __name__ == '__main__':
    app.run(debug=True)

