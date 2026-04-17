<?php

declare(strict_types=1);

namespace Apex\Sdk\Namespaces;

use Apex\Sdk\ApexClient;

class Hr
{
    public readonly HrEmployees $employees;
    public readonly HrLeave $leave;
    public readonly HrPayroll $payroll;

    public function __construct(private readonly ApexClient $client)
    {
        $this->employees = new HrEmployees($client);
        $this->leave = new HrLeave($client);
        $this->payroll = new HrPayroll($client);
    }

    public function calcGosi(array $args): array
    {
        return $this->client->post('/hr/calc/gosi', ['body' => $args])['data'] ?? [];
    }

    public function calcEosb(array $args): array
    {
        return $this->client->post('/hr/calc/eosb', ['body' => $args])['data'] ?? [];
    }
}

class HrEmployees
{
    public function __construct(private readonly ApexClient $client) {}

    public function list(array $opts = []): array
    {
        $params = array_filter([
            'limit'  => $opts['limit']  ?? 25,
            'cursor' => $opts['cursor'] ?? null,
            'status' => $opts['status'] ?? null,
        ], fn($v) => $v !== null);
        $body = $this->client->get('/hr/employees', ['params' => $params]);
        return [
            'items'      => $body['data']       ?? [],
            'nextCursor' => $body['next_cursor'] ?? null,
            'hasMore'    => (bool)($body['has_more'] ?? false),
            'limit'      => $body['limit']      ?? ($opts['limit'] ?? 25),
        ];
    }

    public function create(array $fields): array
    {
        return $this->client->post('/hr/employees', ['body' => $fields])['data'] ?? [];
    }

    public function get(string $id): array
    {
        return $this->client->get("/hr/employees/$id")['data'] ?? [];
    }

    public function update(string $id, array $fields): array
    {
        return $this->client->put("/hr/employees/$id", ['body' => $fields])['data'] ?? [];
    }

    public function terminate(string $id): array
    {
        return $this->client->delete("/hr/employees/$id")['data'] ?? [];
    }
}

class HrLeave
{
    public function __construct(private readonly ApexClient $client) {}

    public function create(array $req): array
    {
        return $this->client->post('/hr/leave-requests', ['body' => $req])['data'] ?? [];
    }

    public function list(?string $status = null): array
    {
        $params = $status !== null ? ['status' => $status] : null;
        return $this->client->get('/hr/leave-requests', ['params' => $params])['data'] ?? [];
    }

    public function approve(string $id): array
    {
        return $this->client->post("/hr/leave-requests/$id/approve")['data'] ?? [];
    }

    public function reject(string $id, string $reason): array
    {
        return $this->client->post(
            "/hr/leave-requests/$id/reject",
            ['params' => ['reason' => $reason]]
        )['data'] ?? [];
    }
}

class HrPayroll
{
    public function __construct(private readonly ApexClient $client) {}

    public function run(string $period): array
    {
        return $this->client->post('/hr/payroll/run', ['body' => ['period' => $period]])['data'] ?? [];
    }

    public function get(string $period): array
    {
        return $this->client->get("/hr/payroll/$period")['data'] ?? [];
    }

    public function approve(string $period): array
    {
        return $this->client->post("/hr/payroll/$period/approve")['data'] ?? [];
    }
}
