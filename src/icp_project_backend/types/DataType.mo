import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Float "mo:base/Float";

module {

    //jenis data crypto yang akan di labeli
    public type DataCryptoItem = {
        id : Text;
        raw_data : Text;
        context : Text;
        is_labeled : Bool;
        current_label : ?Text;
        suggested_label : ?Text;
        labeler_principal : ?Principal;
        validator_principal : ?Principal;
        is_validated : Bool;
        is_correct : ?Bool;
        timestamp : Time.Time;
    };

    public type LabelingLog = {
        long_id : Text;
        principal_id : Principal;
        action_type : Text;
        data_item_id : Text;
        details : Text;
        timestamp : Time.Time;
    };

    public type UserProfile = {
        principal_id : Principal;
        labeled_count : Nat;
        validated_count : Nat;
        reputation_score : Float;
        balance : Nat;
    };

    public type Task = {
        task_id : Text;
        company_principal : Principal;
        data_criteria : DataCriteria;
        total_budget : Nat;
        items_remaining : Nat;
        is_active : Bool;
        timestamp : Time.Time;
    };

    public type DataCriteria = {
        data_type : Text;
        min_amount : Nat;
        labels_categories : [Text];
    };

    public type RewardDistribution = {
        labeler_percentage : Float;
        validator_percentage : Float;
        platform_percentage : Float;
    };

    public type TransactionType = {
        #Deposit : Null;
        #Withdrawal : Null;
        #Reward : Null;
        #Fee : Null;
    };

    public type Transaction = {
        transaction_id : Text;
        sender_principal : ?Principal;
        receive_principal : ?Principal;
        amount : Nat;
        transaction_type : TransactionType;
        related_item_id : ?Text;
        timestamp : Time.Time;
        description : Text;
    };

    public type RewardLog = {
        reward_id : Text;
        item_id : Text;
        labeler_principal : Principal;
        validator_principal : Principal;
        labeler_reward : Nat;
        validator_reward : Nat;
        platform_reward : Nat;
        timestamp : Time.Time;
    };

};
