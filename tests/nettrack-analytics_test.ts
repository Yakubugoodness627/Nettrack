import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Analytics: Can update demand predictions",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Update demand prediction for region 1
        let block = chain.mineBlock([
            Tx.contractCall('nettrack-analytics', 'update-demand-prediction', [
                types.uint(1),      // region-id
                types.uint(1000),   // predicted-demand
                types.uint(85),     // confidence-level
                types.uint(110)     // seasonal-factor
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Verify the prediction was stored
        let query = chain.callReadOnlyFn('nettrack-analytics', 'get-demand-forecast', 
            [types.uint(1)], deployer.address);
        
        const forecast = query.result.expectSome().expectTuple();
        assertEquals(forecast['predicted-demand'], types.uint(1000));
        assertEquals(forecast['confidence-level'], types.uint(85));
        assertEquals(forecast['seasonal-factor'], types.uint(110));
    },
});

Clarinet.test({
    name: "Analytics: Can detect anomalies in distribution patterns",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Set up baseline metrics
        let block = chain.mineBlock([
            Tx.contractCall('nettrack-analytics', 'update-performance-metrics', [
                types.uint(1),      // region-id
                types.uint(95),     // efficiency-score
                types.uint(100),    // target-efficiency
                types.uint(1000),   // nets-distributed
                types.uint(50)      // distribution-cost
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Detect anomalies with low efficiency
        let anomalyBlock = chain.mineBlock([
            Tx.contractCall('nettrack-analytics', 'detect-anomaly', [
                types.uint(1),      // region-id
                types.uint(60),     // current-efficiency (anomalously low)
                types.uint(95),     // expected-efficiency
                types.uint(40)      // threshold
            ], deployer.address)
        ]);
        
        assertEquals(anomalyBlock.receipts[0].result.expectOk(), true);
        
        // Check if alert was generated
        let alerts = chain.callReadOnlyFn('nettrack-analytics', 'get-predictive-alerts', 
            [types.uint(1)], deployer.address);
        
        const alertList = alerts.result.expectOk().expectList();
        assertEquals(alertList.length > 0, true);
    },
});

Clarinet.test({
    name: "Analytics: Can optimize resource allocation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Set resource allocation for multiple regions
        let block = chain.mineBlock([
            Tx.contractCall('nettrack-analytics', 'optimize-resource-allocation', [
                types.uint(1),      // region-id
                types.uint(1000),   // available-nets
                types.uint(500),    // predicted-demand
                types.uint(95)      // target-efficiency
            ], deployer.address),
            Tx.contractCall('nettrack-analytics', 'optimize-resource-allocation', [
                types.uint(2),      // region-id
                types.uint(800),    // available-nets
                types.uint(900),    // predicted-demand
                types.uint(95)      // target-efficiency
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[0].result.expectOk(), true);
        assertEquals(block.receipts[1].result.expectOk(), true);
        
        // Verify resource optimization was calculated
        let optimization = chain.callReadOnlyFn('nettrack-analytics', 'get-resource-optimization', 
            [types.uint(1)], deployer.address);
        
        const result = optimization.result.expectSome().expectTuple();
        assertEquals(result['allocated-nets'], types.uint(500));
        assertEquals(result['efficiency-score'], types.uint(100));
    },
});

Clarinet.test({
    name: "Analytics: Can retrieve comprehensive distribution insights",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Set up test data
        let setupBlock = chain.mineBlock([
            Tx.contractCall('nettrack-analytics', 'update-demand-prediction', [
                types.uint(1), types.uint(1000), types.uint(90), types.uint(105)
            ], deployer.address),
            Tx.contractCall('nettrack-analytics', 'update-performance-metrics', [
                types.uint(1), types.uint(88), types.uint(95), types.uint(950), types.uint(45)
            ], deployer.address)
        ]);
        
        assertEquals(setupBlock.receipts.length, 2);
        
        // Get comprehensive insights
        let insights = chain.callReadOnlyFn('nettrack-analytics', 'get-distribution-insights', 
            [types.uint(1)], deployer.address);
        
        const insightData = insights.result.expectOk().expectTuple();
        assertEquals(insightData['predicted-demand'], types.uint(1000));
        assertEquals(insightData['current-efficiency'], types.uint(88));
        assertEquals(insightData['target-efficiency'], types.uint(95));
    },
});

Clarinet.test({
    name: "Analytics: Access control - only contract owner can update predictions",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        // Try to update prediction as non-owner (should fail)
        let block = chain.mineBlock([
            Tx.contractCall('nettrack-analytics', 'update-demand-prediction', [
                types.uint(1), types.uint(1000), types.uint(85), types.uint(110)
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectErr(types.uint(103)); // ERR-NOT-AUTHORIZED
        
        // Update as owner (should succeed)
        let ownerBlock = chain.mineBlock([
            Tx.contractCall('nettrack-analytics', 'update-demand-prediction', [
                types.uint(1), types.uint(1000), types.uint(85), types.uint(110)
            ], deployer.address)
        ]);
        
        assertEquals(ownerBlock.receipts[0].result.expectOk(), true);
    },
});

Clarinet.test({
    name: "Analytics: Can track performance trends over time",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Update metrics multiple times to simulate trend tracking
        let blocks = [];
        for (let i = 1; i <= 5; i++) {
            let block = chain.mineBlock([
                Tx.contractCall('nettrack-analytics', 'update-performance-metrics', [
                    types.uint(1),               // region-id
                    types.uint(80 + i * 2),      // increasing efficiency
                    types.uint(95),              // target-efficiency
                    types.uint(900 + i * 10),    // increasing nets-distributed
                    types.uint(50 - i)           // decreasing costs
                ], deployer.address)
            ]);
            blocks.push(block);
        }
        
        // All updates should succeed
        blocks.forEach(block => {
            assertEquals(block.receipts[0].result.expectOk(), true);
        });
        
        // Check final metrics show improvement
        let metrics = chain.callReadOnlyFn('nettrack-analytics', 'get-efficiency-metrics', 
            [types.uint(1)], deployer.address);
        
        const metricsData = metrics.result.expectSome().expectTuple();
        assertEquals(metricsData['efficiency-score'], types.uint(90)); // Final efficiency
        assertEquals(metricsData['nets-distributed'], types.uint(950)); // Final distribution count
    },
});

Clarinet.test({
    name: "Analytics: Route optimization calculations work correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Update route optimization for a region
        let block = chain.mineBlock([
            Tx.contractCall('nettrack-analytics', 'update-route-optimization', [
                types.uint(1),      // region-id
                types.uint(250),    // estimated-distance
                types.uint(45),     // estimated-cost
                types.uint(92)      // efficiency-score
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Verify route optimization data
        let route = chain.callReadOnlyFn('nettrack-analytics', 'get-route-optimization', 
            [types.uint(1)], deployer.address);
        
        const routeData = route.result.expectSome().expectTuple();
        assertEquals(routeData['estimated-distance'], types.uint(250));
        assertEquals(routeData['estimated-cost'], types.uint(45));
        assertEquals(routeData['efficiency-score'], types.uint(92));
    },
});

Clarinet.test({
    name: "Analytics: Comprehensive alert system works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Create multiple types of alerts
        let block = chain.mineBlock([
            // Low efficiency anomaly
            Tx.contractCall('nettrack-analytics', 'detect-anomaly', [
                types.uint(1), types.uint(60), types.uint(95), types.uint(30)
            ], deployer.address),
            // Resource optimization needed
            Tx.contractCall('nettrack-analytics', 'optimize-resource-allocation', [
                types.uint(1), types.uint(100), types.uint(500), types.uint(95)
            ], deployer.address),
        ]);
        
        assertEquals(block.receipts.length, 2);
        block.receipts.forEach(receipt => {
            assertEquals(receipt.result.expectOk(), true);
        });
        
        // Check that alerts were generated
        let alerts = chain.callReadOnlyFn('nettrack-analytics', 'get-predictive-alerts', 
            [types.uint(1)], deployer.address);
        
        const alertList = alerts.result.expectOk().expectList();
        assertEquals(alertList.length >= 1, true);
    },
});
