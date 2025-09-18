exports.handleRequest = async function (params) {
    const httpMethod = params.httpMethod || params.method || 'GET';
    const path = params.path || params.resource || '/';
    const queryStringParameters = params.queryStringParameters || {};

    const apiPath = path.replace('/api/orders', '');

    try {
        if (httpMethod !== 'GET') {
            return {
                statusCode: 405,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    success: false,
                    message: 'Method not allowed'
                })
            };
        }

        if (apiPath === '/inventory' || apiPath.includes('inventory')) {
            const productId = queryStringParameters.productId;
            if (!productId) {
                return {
                    statusCode: 400,
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        success: false,
                        message: 'productId 쿼리 파라미터가 필요합니다. 예: /orders/inventory?productId=1'
                    })
                };
            }
            return await getProductInventory(productId);
        } else if (apiPath === '/products' || apiPath === '') {
            return await getProducts();
        }

        return {
            statusCode: 404,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                success: false,
                message: 'Route not found'
            })
        };

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

async function getProductInventory(productId) {
    try {
        const query = `
            SELECT
                p.id,
                p.title,
                p.subtitle,
                p.price,
                p.price_numeric,
                p.image,
                p.category,
                p.type,
                p.badge,
                COALESCE(i.stock_quantity, 0) as stock_quantity,
                CASE
                    WHEN COALESCE(i.stock_quantity, 0) = 0 THEN '매진'
                    ELSE COALESCE(i.stock_quantity, 0)::text
                END as stock_display
            FROM products p
            LEFT JOIN inventory i ON p.id = i.product_id
            WHERE p.id = $1
        `;

        const result = await executeQuery(query, [productId]);

        if (!result.rows || result.rows.length === 0) {
            return {
                statusCode: 404,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    success: false,
                    message: '상품을 찾을 수 없습니다.'
                })
            };
        }

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                product: result.rows[0],
                server_info: {
                    function: 'orders-get',
                    runtime: 'nodejs20',
                    platform: 'samsung-cloud-platform',
                    region: 'kr-west1',
                    response_time: new Date().toISOString()
                }
            })
        };

    } catch (error) {
        console.error('Database error:', error);
        return {
            statusCode: 500,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                success: false,
                message: 'Database error',
                error: error.message
            })
        };
    }
}