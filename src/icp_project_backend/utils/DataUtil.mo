import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Text "mo:base/Text";

actor class generateUUID() {
    stable var counter : Nat = 0;

    public func generate() : async Text {
        let timestamp = Time.now();
        counter += 1;

        let unique_id = debug_show (timestamp) # "-" # Nat.toText(counter);
        return unique_id;
    };

    public func generateWithPrefix(prefix : Text) : async Text {
        let timestamp = Time.now();
        counter += 1;
        let unique_id = prefix # "_" # debug_show (timestamp) # "_" # Nat.toText(counter);
        return unique_id;
    };
};
