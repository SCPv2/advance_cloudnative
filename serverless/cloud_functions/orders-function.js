exports.handleRequest = async function (params) {
    const httpMethod = params.httpMethod || params.method || 'GET';
    const path = params.path || params.resource || '/';
    const pathParameters = params.pathParameters || {};
    const body = params.body || '';
    const queryStringParameters = params.queryStringParameters || {};

    const apiPath = path.replace('/api/orders', '');

    try {
        switch (httpMethod) {
            case 'GET':
                if (apiPath === '/products' || apiPath === '') {
                    return await getProducts();
                } else if (apiPath.startsWith('/products/') && apiPath.includes('/inventory')) {
                    const productId = pathParameters?.productId || apiPath.split('/')[2];
                    return await getProductInventory(productId);
                } else if (apiPath === '/list') {
                    return await getOrderList();
                } else if (apiPath.startsWith('/customer/')) {
                    const customerName = pathParameters?.customerName || decodeURIComponent(apiPath.split('/')[2]);
                    return await getCustomerOrders(customerName);
                } else if (apiPath === '/admin/products') {
                    return await getAdminProducts();
                } else if (apiPath === '/admin/inventory') {
                    return await getAdminInventory();
                }
                break;

            case 'POST':
                const postBody = typeof body === 'string' ? JSON.parse(body) : body;
                if (apiPath === '/create') {
                    return await createOrder(postBody);
                } else if (apiPath === '/admin/reset-inventory') {
                    return await resetInventory();
                } else if (apiPath === '/admin/products') {
                    return await createProduct(postBody);
                } else if (apiPath.startsWith('/admin/inventory/') && apiPath.includes('/add')) {
                    const productId = pathParameters?.productId || apiPath.split('/')[3];
                    return await addInventory(productId, postBody);
                }
                break;

            case 'PUT':
                const putBody = typeof body === 'string' ? JSON.parse(body) : body;
                if (apiPath.startsWith('/admin/products/')) {
                    const productId = pathParameters?.id || apiPath.split('/')[3];
                    return await updateProduct(productId, putBody);
                }
                break;

            case 'DELETE':
                if (apiPath.startsWith('/admin/products/')) {
                    const productId = pathParameters?.id || apiPath.split('/')[3];
                    return await deleteProduct(productId);
                } else if (apiPath.startsWith('/admin/orders/')) {
                    const orderId = pathParameters?.id || apiPath.split('/')[3];
                    return await deleteOrder(orderId);
                }
                break;

            default:
                return {
                    statusCode: 405,
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        success: false,
                        message: 'Method not allowed'
                    })
                };
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

async function getProducts() {
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
            ORDER BY p.id
        `;

        const result = await executeQuery(query);

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS'
            },
            body: JSON.stringify({
                success: true,
                products: result.rows || [],
                server_info: {
                    function: 'orders',
                    runtime: 'nodejs20',
                    platform: 'samsung-cloud-platform',
                    region: 'kr-west1',
                    response_time: new Date().toISOString(),
                    products_count: (result.rows || []).length
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
                message: 'Database connection error',
                error: error.message
            })
        };
    }
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
                product: result.rows[0]
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

async function getOrderList() {
    try {
        const query = `
            SELECT
                o.id,
                o.customer_name,
                p.title as product_title,
                p.subtitle as product_subtitle,
                p.price,
                o.quantity,
                o.unit_price,
                o.total_price,
                o.order_date,
                o.status
            FROM orders o
            JOIN products p ON o.product_id = p.id
            ORDER BY o.order_date DESC
            LIMIT 100
        `;

        const result = await executeQuery(query);

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                orders: result.rows || []
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

async function getCustomerOrders(customerName) {
    try {
        const query = `
            SELECT
                o.id,
                o.customer_name,
                p.title as product_title,
                p.subtitle as product_subtitle,
                p.price,
                o.quantity,
                o.unit_price,
                o.total_price,
                o.order_date,
                o.status
            FROM orders o
            JOIN products p ON o.product_id = p.id
            WHERE o.customer_name = $1
            ORDER BY o.order_date DESC
        `;

        const result = await executeQuery(query, [customerName]);

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                orders: result.rows || []
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

async function resetInventory() {
    try {
        const query = `
            UPDATE inventory
            SET stock_quantity = 100,
                reserved_quantity = 0,
                updated_at = CURRENT_TIMESTAMP
        `;

        const result = await executeQuery(query);

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                message: `모든 상품의 재고가 100개로 리셋되었습니다.`,
                affectedRows: result.rowCount || 0
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

async function getAdminProducts() {
    return { statusCode: 501, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ success: false, message: 'Not implemented' }) };
}

async function getAdminInventory() {
    return { statusCode: 501, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ success: false, message: 'Not implemented' }) };
}

async function createProduct(productData) {
    return { statusCode: 501, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ success: false, message: 'Not implemented' }) };
}

async function updateProduct(productId, productData) {
    return { statusCode: 501, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ success: false, message: 'Not implemented' }) };
}

async function deleteProduct(productId) {
    return { statusCode: 501, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ success: false, message: 'Not implemented' }) };
}

async function addInventory(productId, inventoryData) {
    return { statusCode: 501, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ success: false, message: 'Not implemented' }) };
}

async function deleteOrder(orderId) {
    return { statusCode: 501, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ success: false, message: 'Not implemented' }) };
}