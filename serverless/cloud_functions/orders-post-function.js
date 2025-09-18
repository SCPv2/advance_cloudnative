exports.handleRequest = async function (params) {
    const httpMethod = params.httpMethod || params.method || 'POST';
    const path = params.path || params.resource || '/';
    const body = params.body || '';

    try {
        if (httpMethod !== 'POST') {
            return {
                statusCode: 405,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    success: false,
                    message: 'Method not allowed'
                })
            };
        }

        const orderData = typeof body === 'string' ? JSON.parse(body) : body;
        return await createOrder(orderData);

    } catch (error) {
        console.error('Handler error:', error);
        return {
            statusCode: 500,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                success: false,
                message: 'Internal server error',
                error: error.message
            })
        };
    }
};

async function executeQuery(query, params = []) {
    const https = require('https');
    const querystring = require('querystring');

    const postData = querystring.stringify({
        query: query,
        params: JSON.stringify(params)
    });

    const options = {
        hostname: 'db.creative-energy.net',
        port: 2866,
        path: '/api/query',
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': 'Basic ' + Buffer.from('cedbadmin:cedbadmin123!').toString('base64'),
            'Content-Length': Buffer.byteLength(postData)
        }
    };

    return new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => {
                data += chunk;
            });
            res.on('end', () => {
                try {
                    resolve(JSON.parse(data));
                } catch (e) {
                    reject(e);
                }
            });
        });

        req.on('error', (e) => {
            reject(e);
        });

        req.write(postData);
        req.end();
    });
}

async function createOrder(orderData) {
    const { customerName, productId, quantity } = orderData;

    if (!customerName || !productId || !quantity || quantity <= 0) {
        return {
            statusCode: 400,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                success: false,
                message: '주문 정보가 올바르지 않습니다.'
            })
        };
    }

    try {
        const productQuery = `
            SELECT p.*, i.stock_quantity
            FROM products p
            LEFT JOIN inventory i ON p.id = i.product_id
            WHERE p.id = $1
        `;
        const productResult = await executeQuery(productQuery, [productId]);

        if (!productResult.rows || productResult.rows.length === 0) {
            return {
                statusCode: 404,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    success: false,
                    message: '상품을 찾을 수 없습니다.'
                })
            };
        }

        const product = productResult.rows[0];
        const currentStock = product.stock_quantity || 0;

        if (currentStock < quantity) {
            return {
                statusCode: 400,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    success: false,
                    message: `재고가 부족합니다. (현재 재고: ${currentStock}개)`
                })
            };
        }

        const updateInventoryQuery = `
            UPDATE inventory
            SET stock_quantity = stock_quantity - $1,
                updated_at = CURRENT_TIMESTAMP
            WHERE product_id = $2
            RETURNING stock_quantity
        `;
        const inventoryResult = await executeQuery(updateInventoryQuery, [quantity, productId]);

        const totalPrice = product.price_numeric * quantity;
        const insertOrderQuery = `
            INSERT INTO orders (customer_name, product_id, quantity, unit_price, total_price)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id, order_date
        `;
        const orderResult = await executeQuery(insertOrderQuery, [
            customerName,
            productId,
            quantity,
            product.price_numeric,
            totalPrice
        ]);

        const newStock = inventoryResult.rows[0]?.stock_quantity || 0;

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                message: '주문이 성공적으로 완료되었습니다.',
                order: {
                    id: orderResult.rows[0]?.id,
                    customerName,
                    productTitle: product.title,
                    quantity,
                    totalPrice,
                    orderDate: orderResult.rows[0]?.order_date,
                    remainingStock: newStock
                },
                server_info: {
                    function: 'orders-post',
                    runtime: 'nodejs20',
                    platform: 'samsung-cloud-platform',
                    region: 'kr-west1',
                    response_time: new Date().toISOString()
                }
            })
        };

    } catch (error) {
        console.error('Order creation error:', error);
        return {
            statusCode: 500,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                success: false,
                message: 'Order processing error',
                error: error.message
            })
        };
    }
}