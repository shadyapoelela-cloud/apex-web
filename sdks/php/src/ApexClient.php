<?php
/**
 * APEX PHP SDK — HTTP client.
 *
 * Install: composer require apex/sdk
 *
 * Usage:
 *   use Apex\Sdk\ApexClient;
 *
 *   $apex = new ApexClient([
 *       'base_url'  => 'https://api.apex-app.com',
 *       'api_key'   => 'apex_live_xxx',
 *       'tenant_id' => 't_123',
 *   ]);
 *
 *   foreach ($apex->paginate('/hr/employees', ['limit' => 50]) as $emp) {
 *       echo $emp['employee_number'] . "\n";
 *   }
 *
 *   $sub = $apex->webhooks->subscribe([
 *       'url' => 'https://yourapp.com/hooks/apex',
 *       'events' => ['invoice.created', 'invoice.paid'],
 *   ]);
 */

declare(strict_types=1);

namespace Apex\Sdk;

use GuzzleHttp\Client as HttpClient;
use GuzzleHttp\Exception\ClientException;
use GuzzleHttp\Exception\ServerException;

class ApexApiError extends \RuntimeException
{
    public function __construct(
        public readonly int $statusCode,
        public readonly mixed $detail,
        public readonly string $requestUrl = ''
    ) {
        parent::__construct("APEX API $statusCode: " . json_encode($detail));
    }
}

class ApexClient
{
    public readonly string $baseUrl;
    public readonly ?string $apiKey;
    public readonly ?string $tenantId;
    public readonly float $timeoutSec;

    private HttpClient $http;

    public readonly Namespaces\Hr $hr;
    public readonly Namespaces\Webhooks $webhooks;
    public readonly Namespaces\SavedViews $savedViews;

    public function __construct(array $config)
    {
        $this->baseUrl = rtrim($config['base_url'] ?? '', '/');
        if ($this->baseUrl === '') {
            throw new \InvalidArgumentException('base_url is required');
        }
        $this->apiKey = $config['api_key'] ?? null;
        $this->tenantId = $config['tenant_id'] ?? null;
        $this->timeoutSec = (float)($config['timeout_sec'] ?? 30.0);

        $this->http = $config['http_client'] ?? new HttpClient([
            'base_uri' => $this->baseUrl,
            'timeout'  => $this->timeoutSec,
        ]);

        $this->hr = new Namespaces\Hr($this);
        $this->webhooks = new Namespaces\Webhooks($this);
        $this->savedViews = new Namespaces\SavedViews($this);
    }

    public function headers(array $extra = []): array
    {
        $h = ['Accept' => 'application/json'];
        if ($this->apiKey) {
            $h['Authorization'] = "Bearer {$this->apiKey}";
        }
        if ($this->tenantId) {
            $h['X-Tenant-Id'] = $this->tenantId;
        }
        return array_merge($h, $extra);
    }

    public function request(string $method, string $path, array $options = []): array
    {
        $url = $this->baseUrl . $path;
        $headers = $this->headers();
        if (isset($options['body'])) {
            $headers['Content-Type'] = 'application/json';
        }

        try {
            $resp = $this->http->request($method, $url, [
                'headers' => $headers,
                'query'   => $options['params'] ?? null,
                'json'    => $options['body'] ?? null,
                'http_errors' => false,
            ]);
        } catch (\Throwable $e) {
            throw new ApexApiError(0, ['network' => $e->getMessage()], $url);
        }

        $status = $resp->getStatusCode();
        $raw = (string)$resp->getBody();
        $parsed = $raw === '' ? [] : json_decode($raw, true);
        if ($parsed === null && $raw !== '') {
            $parsed = ['raw' => $raw];
        }

        if ($status >= 400) {
            throw new ApexApiError($status, $parsed, $url);
        }
        return $parsed ?? [];
    }

    public function get(string $path, array $options = []): array
    {
        return $this->request('GET', $path, $options);
    }
    public function post(string $path, array $options = []): array
    {
        return $this->request('POST', $path, $options);
    }
    public function put(string $path, array $options = []): array
    {
        return $this->request('PUT', $path, $options);
    }
    public function delete(string $path, array $options = []): array
    {
        return $this->request('DELETE', $path, $options);
    }

    /**
     * Yield items across all pages via cursor pagination.
     *
     * @return \Generator<int, array>
     */
    public function paginate(string $path, array $opts = []): \Generator
    {
        $limit = $opts['limit'] ?? 25;
        $cursor = null;
        $baseParams = $opts['params'] ?? [];
        while (true) {
            $q = $baseParams + ['limit' => $limit];
            if ($cursor !== null) {
                $q['cursor'] = $cursor;
            }
            $body = $this->get($path, ['params' => $q]);
            foreach (($body['data'] ?? []) as $item) {
                yield $item;
            }
            if (empty($body['has_more']) || empty($body['next_cursor'])) {
                return;
            }
            $cursor = $body['next_cursor'];
        }
    }
}
