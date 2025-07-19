import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Text "mo:base/Text";

module {
    public func generate() : Text {
        let timestamp : Nat64 = Nat64.fromIntWrap(Time.now());
        // Tidak bisa pakai stable var di module, jadi tidak ada counter di sini
        let unique_id = Nat64.toText(timestamp);
        return unique_id;
    };

    public func generateWithPrefix(prefix : Text) : Text {
        let timestamp : Nat64 = Nat64.fromIntWrap(Time.now());
        let unique_id = prefix # "_" # Nat64.toText(timestamp);
        return unique_id;
    };
};
