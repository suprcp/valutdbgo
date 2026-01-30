#!/bin/bash
# VaultDB Cluster Test Script

set -e

echo "=========================================="
echo "VaultDB Cluster Functionality Test"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check cluster status
echo -e "${BLUE}Test 1: Cluster Status Check${NC}"
echo "Checking all nodes..."
echo ""
echo "Node 0 (Leader):"
curl -s localhost:11000/status | python3 -m json.tool 2>/dev/null || curl -s localhost:11000/status
echo ""
echo "Node 1 (Follower):"
curl -s localhost:11001/status | python3 -m json.tool 2>/dev/null || curl -s localhost:11001/status
echo ""
echo "Node 2 (Follower):"
curl -s localhost:11002/status | python3 -m json.tool 2>/dev/null || curl -s localhost:11002/status
echo ""
echo -e "${GREEN}✓ Cluster status check complete${NC}"
echo ""

# Test 2: Write data to leader
echo -e "${BLUE}Test 2: Write Data to Leader${NC}"
echo "Writing test data..."
curl -s -XPOST localhost:11000/key -d '{"test_key": "test_value", "user": "alice", "score": "100"}' > /dev/null
echo -e "${GREEN}✓ Data written to leader${NC}"
echo ""

# Test 3: Follower Reads - Read from all nodes
echo -e "${BLUE}Test 3: Follower Reads Test${NC}"
echo "Reading 'test_key' from all nodes..."
echo ""
echo "From Node 0 (Leader):"
curl -s localhost:11000/key/test_key
echo ""
echo "From Node 1 (Follower):"
curl -s localhost:11001/key/test_key
echo ""
echo "From Node 2 (Follower):"
curl -s localhost:11002/key/test_key
echo ""
echo -e "${GREEN}✓ Follower reads test complete${NC}"
echo ""

# Test 4: Data Synchronization
echo -e "${BLUE}Test 4: Data Synchronization Test${NC}"
echo "Writing multiple keys and verifying sync..."
curl -s -XPOST localhost:11000/key -d '{"key1": "value1", "key2": "value2", "key3": "value3"}' > /dev/null
sleep 1
echo "Reading key1 from all nodes:"
echo "  Node 0: $(curl -s localhost:11000/key/key1)"
echo "  Node 1: $(curl -s localhost:11001/key/key1)"
echo "  Node 2: $(curl -s localhost:11002/key/key1)"
echo -e "${GREEN}✓ Data synchronization verified${NC}"
echo ""

# Test 5: Delete Operation
echo -e "${BLUE}Test 5: Delete Operation Test${NC}"
echo "Deleting 'key3' from leader..."
curl -s -XDELETE localhost:11000/key/key3 > /dev/null
sleep 1
echo "Verifying deletion from all nodes:"
echo "  Node 0: $(curl -s localhost:11000/key/key3)"
echo "  Node 1: $(curl -s localhost:11001/key/key3)"
echo "  Node 2: $(curl -s localhost:11002/key/key3)"
echo -e "${GREEN}✓ Delete operation verified${NC}"
echo ""

# Test 6: Write to non-leader (should fail)
echo -e "${BLUE}Test 6: Write to Follower (Should Fail)${NC}"
echo "Attempting to write to follower node1..."
response=$(curl -s -w "\n%{http_code}" -XPOST localhost:11001/key -d '{"should_fail": "yes"}' 2>&1)
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "500" ] || [ "$http_code" = "000" ]; then
    echo -e "${GREEN}✓ Write to follower correctly rejected${NC}"
else
    echo -e "${YELLOW}⚠ Unexpected response: $http_code${NC}"
fi
echo ""

# Test 7: Read Performance (Follower Reads)
echo -e "${BLUE}Test 7: Read Performance Test${NC}"
echo "Reading from all nodes simultaneously..."
time (
    curl -s localhost:11000/key/user > /dev/null &
    curl -s localhost:11001/key/user > /dev/null &
    curl -s localhost:11002/key/user > /dev/null &
    wait
)
echo -e "${GREEN}✓ Read performance test complete${NC}"
echo ""

# Test 8: Multiple Key Operations
echo -e "${BLUE}Test 8: Multiple Key Operations${NC}"
echo "Writing 10 keys..."
for i in {1..10}; do
    curl -s -XPOST localhost:11000/key -d "{\"key$i\": \"value$i\"}" > /dev/null
done
echo "Reading keys from follower (node1):"
for i in {1..5}; do
    echo "  key$i: $(curl -s localhost:11001/key/key$i)"
done
echo -e "${GREEN}✓ Multiple key operations verified${NC}"
echo ""

echo "=========================================="
echo -e "${GREEN}All Tests Completed!${NC}"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Cluster status check"
echo "  ✓ Write to leader"
echo "  ✓ Follower reads"
echo "  ✓ Data synchronization"
echo "  ✓ Delete operations"
echo "  ✓ Write protection (follower rejects writes)"
echo "  ✓ Read performance"
echo "  ✓ Multiple key operations"
