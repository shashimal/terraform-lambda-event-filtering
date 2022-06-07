const https = require('https');
const AWS = require('aws-sdk');
const ddb = new AWS.DynamoDB({apiVersion: '2012-08-10'});

AWS.config.update({region: 'us-east-1'});

function getUrlStatus(url) {
    return new Promise((resolve, reject) => {
        const req = https.get(url, res => {
            let status = '';

            res.on('data', chunk => {
                status = res.statusCode;
            });

            res.on('end', () => {
                try {
                    resolve(status);
                } catch (err) {
                    reject(status);
                }
            });
        });

        req.on('error', err => {
            reject(500);
        });
    });
}

exports.handler = async event => {
    try {
        for (let index = 0; index < event.Records.length; index++) {
            const record = event.Records[index];
            const {messageAttributes} = record;
            const url = messageAttributes.url.stringValue;
            const name = messageAttributes.name.stringValue;

            const status = await getUrlStatus(url);

            console.log('HTTP Status:️', status);
            const date = new Date();

            const params = {
                TableName: 'UrlStatusChecker-prod',
                Item: {
                    'CreatedTime': {S: date.getTime().toString()},
                    'Timestamp': {N: date.getTime().toString()},
                    'Url': {S: url},
                    'Name': {S: name},
                    'Status': {N: status.toString()}
                }
            }

            const savedData = await ddb.putItem(params).promise();
            console.log("Saved " + savedData.toString())
        }

    } catch
        (error) {
        console.log('Error is:️', error);
        return {
            statusCode: 400,
            body: error.message,
        };
    }
}
