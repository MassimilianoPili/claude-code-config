---
name: activemq-artemis-jms
description: ActiveMQ Artemis message broker patterns for multi-protocol messaging (CORE, AMQP, MQTT, STOMP), Hawtio web console, Docker deployment, Spring Boot JMS integration, and queue/topic management in self-hosted environments.
allowed-tools: Read, Write, Bash, Edit
category: infrastructure
tags: [artemis, activemq, jms, messaging, amqp, mqtt, docker]
version: 1.0.0
---

# ActiveMQ Artemis JMS — SOL Server

## Overview

Apache ActiveMQ Artemis as message broker on SOL server. Supports multiple protocols (CORE/OpenWire, AMQP, MQTT, STOMP). Hawtio web console accessed via OAuth2 Proxy. Internal-only access (Docker network + Tailscale console).

## When to Use

- Configuring messaging for a Spring Boot application
- Managing queues/topics via Hawtio console
- Debugging message delivery issues
- Understanding the multi-protocol setup

## Docker Compose Configuration

```yaml
services:
  artemis:
    image: apache/activemq-artemis:latest
    container_name: artemis
    restart: unless-stopped
    environment:
      ARTEMIS_USER: ${ARTEMIS_USER}
      ARTEMIS_PASSWORD: ${ARTEMIS_PASSWORD}
      EXTRA_ARGS: "--http-host 0.0.0.0 --relax-jolokia"
    volumes:
      - ./data:/var/lib/artemis-instance
    networks:
      - shared

networks:
  shared:
    external: true
```

### Key Configuration

- `EXTRA_ARGS: "--http-host 0.0.0.0 --relax-jolokia"` — Hawtio listens on all interfaces (not just localhost) and allows cross-origin Jolokia access
- Container UID: 1001 (Artemis default)
- Data directory: `./data/` (broker instance + journal)
- Credentials stored in `.env` file (`ARTEMIS_USER`, `ARTEMIS_PASSWORD`)

## Protocols and Ports

| Protocol | Port | Use Case |
|----------|------|----------|
| CORE/OpenWire | 61616 | Java/Spring JMS default |
| AMQP | 5672 | Cross-platform messaging |
| MQTT | 1883 | IoT devices |
| STOMP | 61613 | WebSocket/HTTP clients |
| Hawtio Console | 8161 | Web management |

All ports are internal (Docker network only). Hawtio exposed via nginx + OAuth2 Proxy.

## Access Points

| Method | URL |
|--------|-----|
| Hawtio (Tailscale) | `http://100.86.46.84/mq/` |
| Hawtio (Public) | Not exposed (Tailscale only) |
| Broker (Docker) | `tcp://artemis:61616` |
| AMQP (Docker) | `amqp://artemis:5672` |
| MQTT (Docker) | `mqtt://artemis:1883` |

## nginx Configuration (Hawtio Console)

Artemis uses a special proxy pattern — `$request_uri` is passed directly:

```nginx
location /mq/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    auth_request_set $user $upstream_http_x_auth_request_user;
    auth_request_set $email $upstream_http_x_auth_request_email;
    proxy_set_header X-Forwarded-User $user;
    proxy_set_header X-Forwarded-Email $email;

    set $mq_upstream http://artemis:8161;
    proxy_pass $mq_upstream$request_uri;
    proxy_set_header Host $host;
}
```

Note: `proxy_pass $mq_upstream$request_uri` — the full request URI including `/mq/` is forwarded. Hawtio handles the path internally. This differs from other services that use `rewrite ... break` to strip the prefix.

## Spring Boot Integration

### Dependencies

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-artemis</artifactId>
</dependency>
```

### Configuration

```yaml
spring:
  artemis:
    broker-url: tcp://artemis:61616
    user: ${ARTEMIS_USER}
    password: ${ARTEMIS_PASSWORD}
  jms:
    pub-sub-domain: false  # false = queues (default), true = topics
```

### Producer

```java
@Autowired
private JmsTemplate jmsTemplate;

// Simple string message
jmsTemplate.convertAndSend("my-queue", "Hello");

// With headers/properties
jmsTemplate.convertAndSend("my-queue", payload, message -> {
    message.setStringProperty("source", "my-service");
    return message;
});
```

### Consumer

```java
@JmsListener(destination = "my-queue")
public void receiveMessage(String message) {
    log.info("Received: {}", message);
}

// With concurrency and full JMS message access
@JmsListener(destination = "my-queue", concurrency = "3-10")
public void receiveWithHeaders(Message message) throws JMSException {
    String body = ((TextMessage) message).getText();
    String source = message.getStringProperty("source");
    log.info("From {}: {}", source, body);
}
```

### JSON Message Converter

```java
@Configuration
public class JmsConfig {

    @Bean
    public MessageConverter jacksonJmsMessageConverter() {
        MappingJackson2MessageConverter converter = new MappingJackson2MessageConverter();
        converter.setTargetType(MessageType.TEXT);
        converter.setTypeIdPropertyName("_type");
        return converter;
    }
}
```

With this converter, POJOs are automatically serialized/deserialized:

```java
// Send object
jmsTemplate.convertAndSend("orders", new OrderEvent(orderId, "CREATED"));

// Receive object
@JmsListener(destination = "orders")
public void handleOrder(OrderEvent event) {
    log.info("Order {} status: {}", event.orderId(), event.status());
}
```

## Queue vs Topic Configuration

```java
// Queue (point-to-point) — default
jmsTemplate.convertAndSend("my-queue", message);

// Topic (pub-sub) — requires explicit destination
@Bean
public Topic orderTopic() {
    return new ActiveMQTopic("orders.topic");
}

// Or set globally in application.yml:
// spring.jms.pub-sub-domain: true
```

For mixed queue/topic usage in the same application:

```java
@JmsListener(destination = "my-topic",
             containerFactory = "topicListenerContainerFactory")
public void handleTopic(String message) { ... }

@Bean
public DefaultJmsListenerContainerFactory topicListenerContainerFactory(
        ConnectionFactory connectionFactory) {
    DefaultJmsListenerContainerFactory factory = new DefaultJmsListenerContainerFactory();
    factory.setConnectionFactory(connectionFactory);
    factory.setPubSubDomain(true);
    return factory;
}
```

## Common Operations

```bash
# View logs
docker logs artemis --tail 50

# Follow logs
docker logs artemis -f

# Connect to Artemis CLI
docker exec -it artemis /var/lib/artemis-instance/bin/artemis

# List queues with statistics
docker exec artemis /var/lib/artemis-instance/bin/artemis queue stat

# Create a durable queue
docker exec artemis /var/lib/artemis-instance/bin/artemis queue create \
    --name my-queue --durable --auto-create-address

# Send test message
docker exec artemis /var/lib/artemis-instance/bin/artemis producer \
    --destination my-queue --message-count 1 --message "test"

# Consume messages (reads and removes)
docker exec artemis /var/lib/artemis-instance/bin/artemis consumer \
    --destination my-queue --message-count 1

# Browse messages (read without removing)
docker exec artemis /var/lib/artemis-instance/bin/artemis browser \
    --destination my-queue

# Delete a queue
docker exec artemis /var/lib/artemis-instance/bin/artemis queue delete \
    --name my-queue

# Check data directory permissions (must be UID 1001)
ls -la /data/massimiliano/artemis/data/

# Restart Artemis
cd /data/massimiliano/artemis && docker compose up -d --force-recreate
```

## Broker Configuration (broker.xml)

The broker config is auto-generated at first startup in `./data/etc/broker.xml`. Key sections:

```xml
<!-- Address settings (queue behavior) -->
<address-settings>
    <address-setting match="#">
        <dead-letter-address>DLQ</dead-letter-address>
        <expiry-address>ExpiryQueue</expiry-address>
        <max-delivery-attempts>10</max-delivery-attempts>
        <redelivery-delay>5000</redelivery-delay>
        <auto-create-queues>true</auto-create-queues>
        <auto-create-addresses>true</auto-create-addresses>
    </address-setting>
</address-settings>
```

Modify only if needed — defaults work well for most use cases.

## Best Practices

1. Use `EXTRA_ARGS: "--http-host 0.0.0.0"` so Hawtio is accessible from nginx
2. Use `--relax-jolokia` for cross-origin Jolokia API access from the console
3. Never expose broker ports to host — use Docker network only
4. Data directory must be owned by UID 1001 (`sudo chown -R 1001:1001 ./data/`)
5. Use `spring-boot-starter-artemis` for JMS integration (auto-configures ConnectionFactory)
6. Use `tcp://artemis:61616` for CORE protocol (default and recommended for Spring)
7. Protect Hawtio console with OAuth2 Proxy (never expose 8161 directly)
8. Use durable queues for messages that must survive broker restart
9. Set `concurrency` on `@JmsListener` for parallel message processing
10. Configure dead-letter queues (DLQ) for failed message handling

## Troubleshooting

- **Hawtio shows blank page**: Check `EXTRA_ARGS` includes `--http-host 0.0.0.0` and `--relax-jolokia`
- **Connection refused from Spring Boot**: Verify Artemis is on `shared` network and broker-url uses `artemis:61616`
- **Permission denied on data**: Set ownership to UID 1001 (`sudo chown -R 1001:1001 ./data/`)
- **Queue not created**: Artemis auto-creates queues on first send by default. Check `auto-create-queues` in broker.xml if disabled
- **OAuth2 Proxy 401 on /mq/**: Verify `/oauth2/` location exists on same nginx server block
- **Messages stuck in DLQ**: Check `max-delivery-attempts` in broker.xml and consumer error logs
- **Consumer not receiving**: Verify destination name matches exactly (case-sensitive) and check `pub-sub-domain` setting
- **Slow message processing**: Increase `@JmsListener(concurrency = "3-10")` or check consumer logic for blocking I/O
