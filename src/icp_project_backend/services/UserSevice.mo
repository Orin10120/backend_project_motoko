import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Result "mo:base/Result";
import DataType "../types/DataType";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import DataUtil "../utils/DataUtil";

actor UserService {

    var user_profiles : HashMap.HashMap<Principal, DataType.UserProfile> = HashMap.HashMap(0, Principal.equal, Principal.hash);
    var transactions : [DataType.Transaction] = [];
    var labeling_logs : [DataType.LabelingLog] = [];

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

    public func log_activity(principal : Principal, action : Text, data_item_id : ?Text, details : Text) : async () {
        let new_log_id : Text = DataUtil.generateWithPrefix("logs");

        let non_optional_data_id : Text = switch (data_item_id) {
            case (?value) value;
            case null "";
        };

        let new_log : DataType.LabelingLog = {
            long_id = new_log_id;
            principal_id = principal;
            action_type = action;
            data_item_id = non_optional_data_id;
            details = details;
            timestamp = Time.now();
        };

        labeling_logs := Array.append(labeling_logs, [new_log]);
    };

    public func record_transaction(
        from_p : ?Principal,
        to_p : ?Principal,
        amount_t : Nat,
        tx_type : DataType.TransactionType,
        related_item_id : ?Text,
        memo : Text,
    ) : async () {
        let new_transaction_id : Text = DataUtil.generateWithPrefix("transaction");

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

        transactions := Array.append(transactions, [new_transaction]);
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

    public func get_or_create_user_profile(principal : Principal) : async DataType.UserProfile {
        switch (user_profiles.get(principal)) {
            case (?profile) profile;
            case null {
                let res = await createUserProfile(principal);
                switch (res) {
                    case (#ok(profile)) profile;
                    case (#err(_)) {
                        switch (user_profiles.get(principal)) {
                            case (?profile2) profile2;
                            case null {
                                Debug.trap("Failed to create or get user profile");
                            };
                        };
                    };
                };
            };
        };
    };

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

    public func update_user_labeled_count(principal : Principal) : async Result.Result<Null, Text> {
        switch (user_profiles.get(principal)) {
            case (?profile) {
                user_profiles.put(principal, { profile with labeled_count = profile.labeled_count + 1 });
                return #ok(null);
            };
            case (null) return #err("User profile not found for labeled count update.");
        };
    };

    public func update_user_validated_count(principal : Principal) : async Result.Result<Null, Text> {
        switch (user_profiles.get(principal)) {
            case (?profile) {
                user_profiles.put(principal, { profile with validated_count = profile.validated_count + 1 });
                return #ok(null);
            };
            case (null) return #err("User profile not found for validated count update.");
        };
    };

    // --- Public Functions for User Management ---
    public func deposit(userPrincipal : Principal, amount : Nat) : async Result.Result<Text, Text> {
        let caller = userPrincipal;
        if (Principal.isAnonymous(caller)) {
            return #err("Authentication required.");
        };
        if (amount == 0) {
            return #err("Deposit amount must be greater than zero.");
        };

        let profile = await get_or_create_user_profile(caller);
        let new_balance = profile.balance + amount;
        user_profiles.put(caller, { profile with balance = new_balance });

        await record_transaction(
            ?caller,
            ?Principal.fromActor(UserService),
            amount,
            #Deposit(null),
            null,
            "User deposit",
        );
        await log_activity(caller, "DEPOSIT", null, "Deposited " # Nat.toText(amount));
        return #ok("Deposit successful. Your new balance is: " # Nat.toText(new_balance));
    };

    public func withdraw(userPrincipal : Principal, amount : Nat) : async Result.Result<Text, Text> {
        let caller = userPrincipal;
        if (Principal.isAnonymous(caller)) {
            return #err("Authentication required.");
        };
        if (amount == 0) {
            return #err("Withdrawal amount must be greater than zero.");
        };

        let profile = await get_or_create_user_profile(caller);
        if (profile.balance < amount) {
            return #err("Insufficient balance. Current: " # Nat.toText(profile.balance) # ", Requested: " # Nat.toText(amount));
        };

        let new_balance = profile.balance - amount;
        user_profiles.put(caller, { profile with balance = new_balance });

        await record_transaction(
            ?Principal.fromActor(UserService),
            ?caller,
            amount,
            #Withdrawal(null),
            null,
            "User withdrawal",
        );
        await log_activity(caller, "WITHDRAWAL", null, "Withdrew " # Nat.toText(amount) # " tokens. New balance: " # Nat.toText(new_balance));
        return #ok("Withdrawal successful. Your new balance is: " # Nat.toText(new_balance));
    };

    public query func getMyTransactions(userPrincipal : Principal) : async [DataType.Transaction] {
        let caller = userPrincipal;
        if (Principal.isAnonymous(caller)) { return [] };

        return Array.filter<DataType.Transaction>(
            transactions,
            func(tx) {
                let is_sender = switch (tx.sender_principal) {
                    case (?p) p == caller;
                    case (null) false;
                };
                let is_receiver = switch (tx.receive_principal) {
                    case (?p) p == caller;
                    case (null) false;
                };
                is_sender or is_receiver;
            },
        );
    };

    public query func getPlatformLogs() : async [DataType.LabelingLog] {
        return labeling_logs;
    };

};
