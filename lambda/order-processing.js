const AWS = require('aws-sdk');
AWS.config.update({region: 'us-east-1'});


exports.handler = async function (event, context) {
    console.log(event);
    event.Records.forEach(record => {
        const {body} = record;
        console.log(body);
    });
    return {};
}
