import Foundation

/// Firebase / GA4 ECommerce `items` specification.
///
/// Source: https://firebase.google.com/docs/analytics/measure-ecommerce (captured 2026-05).
/// A spec change is a single edit here — keep this the one place the ECommerce contract lives.
package enum ECommerceItemsSpec {
    /// Reserved ECommerce events that accept an `items` array. `items` is invalid elsewhere.
    package static let itemsEvents: Set<String> = [
        "view_item_list",
        "select_item",
        "view_item",
        "add_to_wishlist",
        "add_to_cart",
        "view_cart",
        "remove_from_cart",
        "begin_checkout",
        "add_shipping_info",
        "add_payment_info",
        "purchase",
        "refund",
        "view_promotion",
        "select_promotion",
    ]

    /// Item-scoped reserved fields and their canonical types. A field named here must use the
    /// matching type. (Event-scoped reserved params like `currency`/`value` are not item fields.)
    package static let reservedFieldTypes: [String: AnalyticsParameterType] = [
        "item_id": .string,
        "item_name": .string,
        "item_brand": .string,
        "item_category": .string,
        "item_variant": .string,
        "price": .double,
        "quantity": .int,
        "index": .int,
        "coupon": .string,
        "item_list_id": .string,
        "item_list_name": .string,
        "discount": .double,
        "affiliation": .string,
        "location_id": .string,
        "promotion_id": .string,
        "promotion_name": .string,
        "creative_name": .string,
        "creative_slot": .string,
    ]

    /// Max number of custom (non-reserved) item-scoped parameters per item.
    package static let maxCustomItemParameters = 27
}
