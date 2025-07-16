import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Result "mo:base/Result";
import DataType "../types/DataType";
import DataUtil "../utils/DataUtil";
import Iter "mo:base/Iter";

actor class UserService(uuid_generator_ref : DataUtil.generateUUID) {
    var user_profiles : HashMap.HashMap<Principal, DataType.UserProfile> = HashMap.HashMap(0, Principal.equal, Principal.hash);
    var transactions : [DataType.Transaction] = [];
    var labeling_logs : [DataType.LabelingLog] = [];

    // let generateUUID = uuid_generator_ref.generate;

    public query func getAllUserProfiles() : async [DataType.UserProfile] {
        return Iter.toArray(user_profiles.vals());
    };

    public func restoreUserProfile(profiles : [DataType.UserProfile]) : async () {
        let mapped = Iter.map<DataType.UserProfile, (Principal, DataType.UserProfile)>(
            profiles.vals(),
            func(profile : DataType.UserProfile) {
                return (profile.principal_id, profile);
            },
        );

        user_profiles := HashMap.fromIter<Principal, DataType.UserProfile>(mapped, 0, Principal.equal, Principal.hash);
    };

    public query func getAllTransaction() : async [DataType.Transaction] {
        return transactions;
    };

    public func restoreTransaction(transaction : [DataType.Transaction]) : async () {
        transactions := transaction;
    };

    public query func getAllLabelingLogs() : async [DataType.LabelingLog] {
        return labeling_logs;
    };

    public query func getUserProfileByPrincipal(principal : Principal) : async ?DataType.UserProfile {
        return user_profiles.get(principal);
    };

    public func restoreLabelingLogs(labeling_log : [DataType.LabelingLog]) : async () {
        labeling_logs := labeling_log;
    };

    public func log_activty(principal : Principal, action : Text, data_item_id : ?Text, details : Text) : async () {

        let new_long_id : Text = await uuid_generator_ref.generateWithPrefix("logs");

        let non_optional_data_id : Text = switch (data_item_id) {
            case (?value) value;
            case null "";
        };

        let new_log : DataType.LabelingLog = {
            long_id = new_long_id;
            principal_id = principal;
            action_type = action;
            data_item_id = non_optional_data_id;
            details = details;
            timestamp = Time.now();
        };

        let old_logs_iter = labeling_logs.vals();
        let new_log_iter = ([new_log] : [DataType.LabelingLog]).vals();
        let combined_iter = {
            next = func() : ?DataType.LabelingLog {
                // Selalu coba ambil dari iterator pertama dulu.
                let first_result = old_logs_iter.next();

                switch (first_result) {
                    // Jika iterator pertama masih punya nilai, kembalikan nilai itu.
                    case (?value) {
                        return ?value;
                    };
                    // Jika iterator pertama sudah habis (null), kembalikan apa pun
                    // hasil dari iterator kedua (bisa nilai, bisa null).
                    case (null) {
                        return new_log_iter.next();
                    };
                };
            };
        };
        labeling_logs := Iter.toArray<DataType.LabelingLog>(combined_iter);
    };

    public func transaction_log(
        from_p : ?Principal,
        to_p : ?Principal,
        amount_t : Nat,
        tx_type : DataType.TransactionType,
        related_item_id : ?Text,
        memo : Text,
    ) : async () {
        let new_transaction_id : Text = await uuid_generator_ref.generateWithPrefix("transaction");

        let new_transaction : DataType.Transaction = {
            transaction_id = new_transaction_id;
            sender_principal = from_p;
            receive_principal = to_p;
            amount = amount_t;
            transaction_type = tx_type;
            related_item_id = related_item_id;
            description = memo;
            timestamp = Time.now();
        };

        let old_transaction_iter = transactions.vals();
        let new_transaction_iter = ([new_transaction] : [DataType.Transaction]).vals();
        let combined_iter = {
            next = func() : ?DataType.Transaction {
                // Selalu coba ambil dari iterator pertama dulu.
                let first_result = old_transaction_iter.next();

                switch (first_result) {
                    // Jika iterator pertama masih punya nilai, kembalikan nilai itu.
                    case (?value) {
                        return ?value;
                    };
                    // Jika iterator pertama sudah habis (null), kembalikan apa pun
                    // hasil dari iterator kedua (bisa nilai, bisa null).
                    case (null) {
                        return new_transaction_iter.next();
                    };
                };
            };
        };
        transactions := Iter.toArray<DataType.Transaction>(combined_iter);
    };

    public func createUserProfile(principal : Principal) : async Result.Result<DataType.UserProfile, Text> {

        if (user_profiles.get(principal) != null) {
            return #err("User profile already exists");
        };

        let new_profile : DataType.UserProfile = {
            principal_id = principal;
            labeled_count = 0;
            validated_count = 0;
            reputation_score = 0.0;
            balance = 0;
        };
        user_profiles.put(principal, new_profile);
        return #ok(new_profile);
    };

    // Helper Function: Add balance
    public func add_balance(principal : Principal, amount : Nat) : async Result.Result<Null, Text> {
        switch (user_profiles.get(principal)) {
            case (?profile) {
                user_profiles.put(principal, { profile with balance = profile.balance + amount });
                return #ok(null);
            };
            case (null) {
                return #err("User profile not found for balance update.");
            };
        };
    };

    // Helper Function: Update labeled count
    public func update_user_labeled_count(principal : Principal) : async Result.Result<Null, Text> {
        switch (user_profiles.get(principal)) {
            case (?profile) {
                user_profiles.put(principal, { profile with labeled_count = profile.labeled_count + 1 });
                return #ok(null);
            };
            case (null) return #err("User profile not found for labeled count update.");
        };
    };

    // Helper Function: Update validated count
    public func update_user_validated_count(principal : Principal) : async Result.Result<Null, Text> {
        switch (user_profiles.get(principal)) {
            case (?profile) {
                user_profiles.put(principal, { profile with validated_count = profile.validated_count + 1 });
                return #ok(null);
            };
            case (null) return #err("User profile not found for validated count update.");
        };
    };

    // // --- Public Functions for User Management ---
    // public func deposit(userPrincipal : Principal, amount : Nat) : async Result.Result<Text, Text> {
    //     let caller = userPrincipal;
    //     if (caller == Principal.anonymous()) {
    //         return #err("Authentication required.");
    //     };
    //     if (amount == 0) {
    //         return #err("Deposit amount must be greater than zero.");
    //     };

    //     let creation_result = await createUserProfile(caller);

    //      let profile : DataType.UserProfile = switch (await createUserProfile(caller)) {
    //     case (#ok(p)) {
    //         p;
    //     };
    //     case (#err(e)) {
    //         return #err("Failed to get or create profile: " # e);
    //     };

    //     let new_balance = profile.balance + amount;
    //     user_profiles.put(caller, { profile with balance = new_balance });

    //     await transaction_log(
    //         ?caller,
    //         ?Actor.self(),
    //         amount,
    //         #Deposit(null),
    //         null,
    //         ?"User deposit",
    //     );
    //     await log_activity(caller, "DEPOSIT", null, "Deposited ");
    //     return #ok("Deposit successful. Your new balance is: ");
    // };

    // public func withdraw(userPrincipal : Principal, amount : Nat) : async Result.Result<Text, Text> {
    //     let caller = userPrincipal;
    //     if (caller == Principal.anonymous()) {
    //         return #err("Authentication required.");
    //     };
    //     if (amount == 0) {
    //         return #err("Withdrawal amount must be greater than zero.");
    //     };

    //     let profile = await get_or_create_user_profile(caller);
    //     if (profile.balance < amount) {
    //         return #err("Insufficient balance. Current: " # Debug.show(profile.balance) # ", Requested: " # Debug.show(amount));
    //     };

    //     let new_balance = profile.balance - amount;
    //     user_profiles.put(caller, { profile with balance = new_balance });

    //     await record_transaction(
    //         ?Principal.fromActor(this),
    //         ?caller,
    //         amount,
    //         #Withdrawal(null), // Variant types need a value, even if it's Null
    //         null,
    //         ?"User withdrawal",
    //     );
    //     await log_activity(caller, "WITHDRAWAL", null, "Withdrew " # Debug.show(amount) # " tokens. New balance: " # Debug.show(new_balance));
    //     return #ok("Withdrawal successful. Your new balance is: " # Debug.show(new_balance));
    // };

    // public query func getMyTransactions(userPrincipal : Principal) : async [DataType.Transaction] {
    //     let caller = msg.caller();
    //     if (caller == Principal.anonymous()) { return [] };

    //     // FIX: Use Array.filter for filtering
    //     return Array.filter<DataType.Transaction>(
    //         transactions,
    //         func(tx) {
    //             // IMPROVEMENT: Use a safer way to check optionals
    //             let is_sender = switch (tx.sender_principal) {
    //                 case (?p) p == caller;
    //                 case (null) false;
    //             };
    //             let is_receiver = switch (tx.receive_principal) {
    //                 case (?p) p == caller;
    //                 case (null) false;
    //             };
    //             return is_sender or is_receiver;
    //         },
    //     );
    // };

    // public query func getPlatformLogs() : async [DataType.LabelingLog] {
    //     return labeling_logs;
    // };

};
