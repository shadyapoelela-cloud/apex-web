<?php

declare(strict_types=1);

namespace Apex\Sdk\Namespaces;

use Apex\Sdk\ApexClient;

class Webhooks
{
    public function __construct(private readonly ApexClient $client) {}

    /** Subscribe to events. Returns payload including the secret (save it). */
    public function subscribe(array $args): array
    {
        return $this->client->post(
            '/api/v1/webhooks/subscriptions',
            ['body' => array_merge(['name' => null], $args)]
        )['data'] ?? [];
    }

    public function list(): array
    {
        return $this->client->get('/api/v1/webhooks/subscriptions')['data'] ?? [];
    }

    public function unsubscribe(string $id): array
    {
        return $this->client->delete("/api/v1/webhooks/subscriptions/$id")['data'] ?? [];
    }

    public function deliveries(array $opts = []): array
    {
        $params = array_filter([
            'status' => $opts['status'] ?? null,
            'limit'  => $opts['limit']  ?? 50,
        ], fn($v) => $v !== null);
        return $this->client->get('/api/v1/webhooks/deliveries', ['params' => $params])['data'] ?? [];
    }

    public function retryDelivery(string $id): array
    {
        return $this->client->post("/api/v1/webhooks/deliveries/$id/retry")['data'] ?? [];
    }

    /**
     * Verify an incoming webhook signature.
     *
     * @param string $secret    Subscription's secret (whsec_...)
     * @param string $body      Raw request body bytes
     * @param string $signature The X-Apex-Signature header value
     */
    public static function verifySignature(string $secret, string $body, string $signature): bool
    {
        if (!str_starts_with($signature, 'sha256=')) {
            return false;
        }
        $expected = 'sha256=' . hash_hmac('sha256', $body, $secret);
        return hash_equals($expected, $signature);
    }
}

class SavedViews
{
    public function __construct(private readonly ApexClient $client) {}

    public function list(string $screen): array
    {
        return $this->client->get(
            '/api/v1/saved-views',
            ['params' => ['screen' => $screen]]
        )['data'] ?? [];
    }

    public function create(array $args): array
    {
        return $this->client->post('/api/v1/saved-views', ['body' => array_merge([
            'is_shared' => false,
        ], $args)])['data'] ?? [];
    }

    public function update(string $id, array $args): array
    {
        return $this->client->put("/api/v1/saved-views/$id", ['body' => $args])['data'] ?? [];
    }

    public function delete(string $id): array
    {
        return $this->client->delete("/api/v1/saved-views/$id")['data'] ?? [];
    }
}
