/**
 * Samsung Cloud Platform - Cloud Functions
 * Creative Energy Orders API (Simple Version)
 * Node.js 20 Runtime
 */

exports.handleRequest = async function (params) {
    try {
        // SCP Cloud Functions에서 매개변수 구조 파싱
        const httpMethod = params.httpMethod || params.method || 'GET';
        const path = params.path || params.resource || '/';
        const body = params.body || '';

        console.log('Request received:', { httpMethod, path });

        // Parse the API path
        const apiPath = path.replace('/api/orders', '');

        // Route handling
        if (httpMethod === 'GET' && (apiPath === '/products' || apiPath === '')) {
            return await getProducts();
        } else if (httpMethod === 'POST' && apiPath === '/create') {
            const orderData = typeof body === 'string' ? JSON.parse(body) : body;
            return await createOrder(orderData);
        }

        // Default response
        return {
            statusCode: 404,
            body: JSON.stringify({
                success: false,
                message: 'Route not found'
            })
        };

    } catch (error) {
        console.error('Handler error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({
                success: false,
                message: 'Internal server error',
                error: error.message
            })
        };
    }
};

/**
 * Get products list
 */
async function getProducts() {
    try {
        // Mock data for testing
        const mockProducts = [
            {
                id: 1,
                title: "Ellie 'Multiverse' Official Album",
                subtitle: "1st Full Album - Limited Edition",
                price: "₩25,000",
                price_numeric: 25000,
                image: "media/img/ellie-album.jpg",
                category: "음반",
                type: "album",
                badge: "HOT",
                stock_quantity: 50,
                stock_display: "50"
            }
        ];

        return {
            statusCode: 200,
            body: JSON.stringify({
                success: true,
                products: mockProducts,
                server_info: {
                    function: 'orders',
                    runtime: 'nodejs20',
                    platform: 'samsung-cloud-platform',
                    region: 'kr-west1',
                    response_time: new Date().toISOString(),
                    products_count: mockProducts.length
                }
            })
        };

    } catch (error) {
        console.error('Get products error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({
                success: false,
                message: 'Database connection error',
                error: error.message
            })
        };
    }
}

/**
 * Create order
 */
async function createOrder(orderData) {
    try {
        const { customerName, productId, quantity } = orderData;

        // Validate input
        if (!customerName || !productId || !quantity) {
            return {
                statusCode: 400,
                body: JSON.stringify({
                    success: false,
                    message: '주문 정보가 올바르지 않습니다.'
                })
            };
        }

        // Mock order creation
        const mockOrder = {
            id: Date.now(),
            customerName,
            productTitle: "Test Product",
            quantity,
            totalPrice: 25000 * quantity,
            orderDate: new Date().toISOString()
        };

        return {
            statusCode: 200,
            body: JSON.stringify({
                success: true,
                message: '주문이 성공적으로 완료되었습니다.',
                order: mockOrder
            })
        };

    } catch (error) {
        console.error('Order creation error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({
                success: false,
                message: 'Order processing error',
                error: error.message
            })
        };
    }
}