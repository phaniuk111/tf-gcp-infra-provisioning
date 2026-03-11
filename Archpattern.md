# API Response-Shaping Approaches for Internal APIs

This README compares three common approaches for handling large internal REST APIs where different consumers need different subsets of fields:

- **REST + Projection / Sparse Fieldsets**
- **BFF (Backend for Frontend)**
- **GraphQL**

This is especially relevant for APIs with:
- large payloads (for example, 300 fields)
- many internal consumers
- different consumer-specific field needs

---

## Comparison Table

| Aspect | REST + Projection / Sparse Fieldsets | BFF (Backend for Frontend) | GraphQL |
|---|---|---|---|
| Main idea | One REST API lets clients choose fields with `fields=`, `include=`, `profile=` | Separate service shapes data for a client type | Client asks exactly for the fields it needs |
| Where complexity sits | API design and backend implementation | Runtime architecture and service ownership | Schema, resolvers, query execution |
| Client-side effort | Low to medium | Low for client | Medium to high |
| Infra / ops overhead | Low | High | Medium |
| Number of deployables | Usually unchanged | Increases | Adds GraphQL gateway/service |
| Good for many consumers | Yes | Only if grouped by experience | Yes |
| Good for highly varied payload needs | Moderate to high | High | Very high |
| Risk of service explosion | None | High if done per client | Low |
| Risk of query complexity | Low | Low | High if unmanaged |
| Payload efficiency | Good | Good | Excellent |
| Backend code complexity | Medium | Medium | High |
| Operational complexity in Kubernetes | Low | High | Medium |
| Best fit for internal APIs | Very common | Only for distinct client experiences | Less common than REST internally |
| Rework for existing clients | Very low | Low | Moderate |
| Ease of gradual adoption | Easy | Moderate | Moderate |
| Ownership model | Backend/API team | Platform + app teams | Backend/API team |
| Caching simplicity | Easier | Medium | Harder |
| Monitoring/debugging | Easier | Harder due to extra hop | Harder due to dynamic queries |
| Typical use case | Large REST API with many optional fields | Mobile/web/partner-specific experience APIs | Many consumers with very different data needs |
| Main downside | Can get messy with many nested combinations | Turns API problem into service sprawl | More dev sophistication required |

---

## Simple Mental Model

| Pattern | Interpretation |
|---|---|
| REST + Projection | Make the API smarter |
| BFF | Add another layer to shape responses |
| GraphQL | Let clients define the response |

---

## When Each Approach Fits Best

| Main problem | Better fit |
|---|---|
| Too many fields in one REST payload | REST + Projection |
| Web and mobile need very different aggregated responses | BFF |
| Hundreds of consumers need highly custom field combinations | GraphQL or Projection first |
| Need least infra overhead | REST + Projection |
| Need least client rework | REST + Projection or BFF |
| Need maximum flexibility | GraphQL |

---

## Recommendation for an Internal API with 300 Fields

For an internal API with:
- around 300 fields
- many consumers
- a desire to avoid unnecessary infrastructure complexity

A practical order of preference is usually:

1. **REST + projection/profile/include**
2. **BFF only for true experience-specific consumers**
3. **GraphQL only if flexibility needs become extreme**

---

## Why REST + Projection Is Usually the First Choice

This approach keeps the architecture simpler while still allowing response flexibility.

Examples:

```http
GET /account/123
GET /account/123?profile=summary
GET /account/123?profile=detailed
GET /account/123?fields=id,name,status
GET /account/123?profile=summary&include=transactions
