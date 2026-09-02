var ALLOW_ORIGIN = process.env.ALLOW_ORIGIN;

var CATALOG = [
    {"id":1,"title":"BigBoys 1st Full Album [SimplyFit] Standard Edition","subtitle":"Standard Edition","price_numeric":18500,"image":"media/img/bb_prod1.png","category":"bigboys","type":"album","badge":"NEW","stock_quantity":100,"sold_out":false},
    {"id":2,"title":"BigBoys 1st Full Album [SimplyFit] Limited Edition","subtitle":"with Photo Book & Photo Cards","price_numeric":35000,"image":"media/img/bb_prod2.png","category":"bigboys","type":"album","badge":"LIMITED","stock_quantity":100,"sold_out":false},
    {"id":3,"title":"BigBoys Official Light Stick","subtitle":"Ver. 1.0","price_numeric":42000,"image":"media/img/bb_prod3.png","category":"bigboys","type":"goods","badge":"LIMITED","stock_quantity":12,"sold_out":false},
    {"id":4,"title":"BigBoys Official T-Shirt","subtitle":"Black / White Available","price_numeric":28000,"image":"media/img/bb_prod4.png","category":"bigboys","type":"goods","badge":null,"stock_quantity":100,"sold_out":false},
    {"id":5,"title":"Cloudy 2nd Official Album [JUMP]","subtitle":"Purple Ver.","price_numeric":16800,"image":"media/img/cloudy_prod1.png","category":"cloudy","type":"album","badge":"NEW","stock_quantity":100,"sold_out":false},
    {"id":6,"title":"Cloudy 1st Official Album [In the Sky]","subtitle":"Sky Blue Ver.","price_numeric":16800,"image":"media/img/cloudy_prod2.png","category":"cloudy","type":"album","badge":null,"stock_quantity":0,"sold_out":true},
    {"id":7,"title":"Cloudy Official Merchandise","subtitle":"Eco Bag","price_numeric":40000,"image":"media/img/cloudy_prod3.png","category":"cloudy","type":"goods","badge":"LIMITED","stock_quantity":45,"sold_out":false},
    {"id":8,"title":"Cloudy Official Light Stick","subtitle":"Ver. 2.0","price_numeric":42000,"image":"media/img/cloudy_prod4.png","category":"cloudy","type":"goods","badge":null,"stock_quantity":100,"sold_out":false}
];

exports.handleRequest = async function (params) {
    var q = params && params.queryStringParameters ? params.queryStringParameters : {};
    var list = CATALOG;

    if (q.category && q.category !== 'all') {
        list = list.filter(function (item) { return item.category === q.category })
    }
    if (q.type) {
        list = list.filter(function (item) { return item.type === q.type })
    }

    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Access-Control-Allow-Origin': ALLOW_ORIGIN
        },
        body: JSON.stringify({ success: true, products: list })
    }
};
