# Abuse Control Reference

This reference captures a minimal anti-brush and rate-limit design for the
current single-host deployment, using Redis as the coordination layer.

## Registration Guard

Use a short-window guard before account creation to limit bot bursts from the
same IP and device fingerprint.

```go
func AllowRegistration(ctx context.Context, ip string, deviceID string, redis redis.Cmdable) (bool, error) {
	key := fmt.Sprintf("register:%s:%s", ip, deviceID)

	count, err := redis.Incr(ctx, key).Result()
	if err != nil {
		return false, err
	}
	if count == 1 {
		if err := redis.Expire(ctx, key, 15*time.Minute).Err(); err != nil {
			return false, err
		}
	}

	return count <= 5, nil
}
```

## Token Bucket With Redis

Prefer a Redis-backed `Token Bucket` for login, send-message, add-friend, and
media-upload endpoints so every gateway instance shares the same budget state.

```lua
local tokens_key = KEYS[1]
local ts_key = KEYS[2]
local rate = tonumber(ARGV[1])
local capacity = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local requested = tonumber(ARGV[4])

local last_tokens = tonumber(redis.call("GET", tokens_key) or capacity)
local last_ts = tonumber(redis.call("GET", ts_key) or now)
local delta = math.max(0, now - last_ts)
local filled = math.min(capacity, last_tokens + (delta * rate))

if filled < requested then
  redis.call("SET", tokens_key, filled)
  redis.call("SET", ts_key, now)
  return {0, filled}
end

local remaining = filled - requested
redis.call("SET", tokens_key, remaining)
redis.call("SET", ts_key, now)
return {1, remaining}
```

## Middleware Usage

```go
type RateLimitDimensions struct {
	AccountID string
	DeviceID  string
	IP        string
	Endpoint  string
}

func EnforceTokenBucket(ctx context.Context, dims RateLimitDimensions, requested int64) error {
	keys := []string{
		fmt.Sprintf("bucket:%s:%s", dims.Endpoint, dims.AccountID),
		fmt.Sprintf("bucket_ts:%s:%s", dims.Endpoint, dims.AccountID),
	}
	result, err := redisClient.Eval(ctx, tokenBucketLua, keys,
		2.0,   // refill rate per second
		20,    // bucket capacity
		time.Now().Unix(),
		requested,
	).Result()
	if err != nil {
		return err
	}

	allowed := result.([]interface{})[0].(int64) == 1
	if !allowed {
		return ErrRateLimited
	}
	return nil
}
```

## Recommended Dimensions

- account ID
- device ID
- IP
- endpoint name
- app version
- network type

Store high-risk counters on several axes at once so abuse can be blocked even
when the attacker rotates one identity dimension.

## Leaky Bucket Alternative

- Use a leaky bucket for expensive asynchronous work such as avatar OCR,
  invitation fan-out, or large attachment uploads.
- Keep the ingress queue in Redis streams or Kafka and drain it at a fixed rate
  to avoid backend overload.

## Operational Guardrails

- Return consistent `429` responses with retry-after metadata.
- Log every reject with account ID, device ID, IP, endpoint name, and current
  bucket state.
- Protect registration, login, OTP send, password reset, and message send with
  independent budgets rather than a single global limit.
