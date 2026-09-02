var PROTOCOL = process.env.OBJECT_STORAGE_PROTOCOL;
var HOST = process.env.OBJECT_STORAGE_HOST;
var BUCKET = process.env.OBJECT_STORAGE_BUCKET;
var PRODUCTS_KEY = process.env.PRODUCTS_KEY;
var INVENTORY_KEY = process.env.INVENTORY_KEY;
var ALLOW_ORIGIN = process.env.ALLOW_ORIGIN;

async function load(key) {
    var r = await fetch(PROTOCOL + HOST + '/' + BUCKET + '/' + key);
    var t = await r.text();
    return JSON.parse(t)
}

exports.handleRequest = async function (params) {
    var q = params && params.queryStringParameters ? params.queryStringParameters : {};
    var p = await load(PRODUCTS_KEY);
    var i = await load(INVENTORY_KEY);

    var stock = {};
    i.inventory.forEach(function (row) {
        stock[row.product_id] = row.stock_quantity - row.reserved_quantity;
    });

    var list = p.products.map(function (item) {
        var n = stock[item.id] || 0;
        item.stock_quantity = n;
        item.sold_out = n === 0;
        return item
    });

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
