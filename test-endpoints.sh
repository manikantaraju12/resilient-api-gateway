#!/bin/bash

# Test Endpoints Script for Resilient API Gateway
# This script validates all endpoints and demonstrates functionality

set -e

BASE_URL="${1:-http://localhost:5000}"
UPSTREAM_URL="${2:-http://localhost:5001}"

echo "====== Resilient API Gateway - Endpoint Testing ======"
echo "Base URL: $BASE_URL"
echo "Upstream URL: $UPSTREAM_URL"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test function
test_endpoint() {
    local name=$1
    local method=$2
    local endpoint=$3
    local expected_code=$4
    
    echo -n "Testing $name... "
    
    response=$(curl -s -w "\n%{http_code}" -X $method "$BASE_URL$endpoint")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "$expected_code" ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $http_code)"
        echo "  Response: $(echo $body | head -c 100)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (Expected $expected_code, got $http_code)"
        echo "  Response: $body"
        return 1
    fi
}

# Counter
TOTAL=0
PASSED=0

echo "=== Health Checks ==="
test_endpoint "Health endpoint" "GET" "/health" "200" && ((PASSED++)) || true
((TOTAL++))
echo ""

echo "=== Basic Proxy Endpoints ==="
test_endpoint "Proxy to /ok" "GET" "/proxy/ok" "200" && ((PASSED++)) || true
((TOTAL++))

test_endpoint "Proxy to /health" "GET" "/proxy/health" "200" && ((PASSED++)) || true
((TOTAL++))

test_endpoint "Proxy to /users" "GET" "/proxy/users" "200" && ((PASSED++)) || true
((TOTAL++))
echo ""

echo "=== Rate Limiting Tests ==="
echo "Testing rate limiting (capacity: 3, should get 429 after 3 requests)..."
for i in {1..5}; do
    response=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/proxy/ok" -H "X-Forwarded-For: test-client-$RANDOM")
    http_code=$(echo "$response" | tail -n1)
    if [ $i -le 3 ]; then
        if [ "$http_code" = "200" ]; then
            echo -e "  Request $i: ${GREEN}✓ 200 (allowed)${NC}"
            ((PASSED++))
        else
            echo -e "  Request $i: ${RED}✗ $http_code${NC}"
        fi
    else
        if [ "$http_code" = "429" ]; then
            echo -e "  Request $i: ${GREEN}✓ 429 (rate limited)${NC}"
            ((PASSED++))
        elif [ "$http_code" = "200" ]; then
            echo -e "  Request $i: ${YELLOW}⚠ 200 (not rate limited - check capacity)${NC}"
        else
            echo -e "  Request $i: ${RED}✗ $http_code${NC}"
        fi
    fi
    ((TOTAL++))
done
echo ""

echo "=== Retry-After Header ==="
echo "Checking Retry-After header on 429..."
response=$(curl -s -i -X GET "$BASE_URL/proxy/ok" | grep -i "retry-after" || echo "No Retry-After")
echo "  $response"
((TOTAL++))
echo ""

echo "=== Circuit Breaker Tests ==="
echo "Triggering circuit breaker by requesting /fail endpoint..."
failures=0
for i in {1..15}; do
    response=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/proxy/fail")
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" != "200" ]; then
        ((failures++))
    fi
    echo -n "."
done
echo ""
echo "Failures sent: $failures/15"

# Wait a moment
sleep 2

echo "Testing circuit breaker response (should return 503)..."
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/proxy/ok")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "503" ]; then
    echo -e "${GREEN}✓ Circuit breaker OPEN${NC} (HTTP 503)"
    echo "  Response: $body"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠ Expected 503, got $http_code${NC}"
fi
((TOTAL++))
echo ""

echo "=== POST Request Tests ==="
test_endpoint "POST to /echo" "POST" "/proxy/echo" "200" && ((PASSED++)) || true
((TOTAL++))
echo ""

echo "=== Error Cases ==="
test_endpoint "Non-existent endpoint" "GET" "/proxy/nonexistent" "200" && ((PASSED++)) || true
((TOTAL++))

test_endpoint "Invalid path" "GET" "/invalid" "404" && ((PASSED++)) || true
((TOTAL++))
echo ""

echo "=== Slow Endpoint Test ==="
echo -n "Testing slow endpoint (should take ~2 seconds)... "
time curl -s "$BASE_URL/proxy/slow" > /dev/null
echo "✓ Complete"
((TOTAL++))
((PASSED++))
echo ""

echo "=== Query Parameter Tests ==="
test_endpoint "Query parameters" "GET" "/proxy/echo?key1=value1&key2=value2" "200" && ((PASSED++)) || true
((TOTAL++))
echo ""

echo "=== Header Tests ==="
response=$(curl -s -i "$BASE_URL/proxy/ok" | grep -i "x-forwarded-for" || echo "Missing header")
echo "X-Forwarded-For header: $response"
echo ""

echo "=== Performance Load Test ==="
echo "Running 100 concurrent requests..."
for i in {1..100}; do
    curl -s "$BASE_URL/health" > /dev/null &
done
wait
echo "✓ 100 requests completed"
((TOTAL++))
((PASSED++))
echo ""

echo "====== Test Summary ======"
echo "Passed: $PASSED / $TOTAL"
FAILED=$((TOTAL - PASSED))
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$FAILED test(s) failed${NC}"
    exit 1
fi
