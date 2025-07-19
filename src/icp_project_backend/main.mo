import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";
import Bool "mo:base/Bool";
import Text "mo:base/Text";
import Nat "mo:base/Nat";

actor {
    // Task Object
    type Task = {
        id : Nat;
        companyId : Text;
        validatorId : Text;
        workerId : Text;
        prize : Nat;
        deadline : Time.Time;
        valid : Bool;
    };

    public type UserRole = {
        #Admin;
        #User;
        #Labeler;
    };

    public type UserProfile = {
        id : Text;
        balance : Nat;
        tasksCompleted : Nat;
        role : UserRole;
    };

    let adminId : Text = "a7db5377686c7a0a34b2c99ccdbf3b727794f3341b88182f79ed287ccfec38bd";
    let labelerId : Text = "b7db5377686c7a0a34b2c99ccdbf3b727794f3341b88182f79ed287ccfec38bd";

    var userProfiles = HashMap.HashMap<Text, UserProfile>(0, Text.equal, Text.hash);
    // HashMap for all the tasks
    let tasks = HashMap.HashMap<Text, Task>(0, Text.equal, Text.hash);
    // ID for a task
    var presentId : Nat = 0;

    func get_or_create_profile(userId : Text) : UserProfile {
        switch (userProfiles.get(userId)) {
            case (?profile) {
                // Jika profil sudah ada, kembalikan profil tersebut
                return profile;
            };
            case (null) {
                let userRole : UserRole = if (userId == adminId) {
                    #Admin;
                } else if (userId == labelerId) {
                    #Labeler;
                } else {
                    #User; // Default role for other users
                };

                // Jika profil belum ada, buat yang baru
                let newProfile : UserProfile = {
                    id = userId;
                    balance = 0;
                    tasksCompleted = 0;
                    role = userRole;
                };
                // Simpan profil baru, lalu kembalikan
                userProfiles.put(userId, newProfile);
                return newProfile;
            };
        };
    };

    // make a new task on makeTask public function
    public shared func makeTask(companyId : Text, validatorId : Text, prize : Nat, deadline : Time.Time) : async Result.Result<Text, Text> {
        if (companyId == "" or validatorId == "") {
            return #err("ID cannot be empty");
        };
        if (prize == 0) {
            return #err("Prize cannot be 0");
        };

        presentId += 1;
        // make a new task
        let task : Task = {
            id = presentId;
            companyId = companyId;
            validatorId = validatorId;
            workerId = "";
            prize = prize;
            deadline = deadline;
            valid = false;
        };

        tasks.put(Nat.toText(presentId), task);
        return #ok("success");
    };

    // Take a task on takeTask function
    public shared func takeTask(worker : Text, taskId : Text) : async Result.Result<Text, Text> {
        // get a task from the HashMap
        let existingTask = tasks.get(taskId);
        switch (existingTask) {
            case null {
                return #err("Task not found");
            };
            case (?task) {
                let updatedTask : Task = {
                    id = task.id;
                    companyId = task.companyId;
                    validatorId = task.validatorId;
                    workerId = worker;
                    prize = task.prize;
                    deadline = task.deadline;
                    valid = task.valid;
                };

                // update the existing task in HashMap
                tasks.put(taskId, updatedTask);
                return #ok("Task updated");
            };
        };
    };

    public shared func validateTask(validatorId : Text, taskId : Text) : async Result.Result<Text, Text> {
        switch (tasks.get(taskId)) {
            case null {
                return #err("Tugas tidak ditemukan");
            };
            case (?task) {
                // Keamanan: Pastikan yang memvalidasi adalah validator yang sah
                if (task.validatorId != validatorId) {
                    return #err("Anda bukan validator untuk tugas ini.");
                };
                // Pastikan tugas sudah ada yang mengerjakan
                if (task.workerId == "") {
                    return #err("Tugas ini belum diambil oleh pekerja.");
                };
                // Hindari validasi ulang
                if (task.valid) {
                    return #err("Tugas ini sudah divalidasi sebelumnya.");
                };

                // Update status 'valid' menjadi true
                let validatedTask : Task = { task with valid = true };
                tasks.put(taskId, validatedTask);

                return #ok("Tugas berhasil divalidasi. Worker sekarang bisa mengklaim hadiah.");
            };
        };
    };

    public shared func claimReward(workerId : Text, taskId : Text) : async Result.Result<Text, Text> {
        switch (tasks.get(taskId)) {
            case null { return #err("Tugas tidak ditemukan") };
            case (?task) {
                if (task.workerId != workerId) {
                    return #err("Anda bukan pekerja untuk tugas ini.");
                };
                if (not task.valid) {
                    return #err("Tugas belum divalidasi. Anda belum bisa mengklaim hadiah.");
                };

                let workerProfile = get_or_create_profile(workerId);

                let updatedProfile : UserProfile = {
                    workerProfile with
                    balance = workerProfile.balance + task.prize;
                    tasksCompleted = workerProfile.tasksCompleted + 1;
                };
                userProfiles.put(workerId, updatedProfile);

                tasks.delete(taskId);

                let rewardMessage = "Selamat! Hadiah sebesar " # Nat.toText(task.prize) # " berhasil diklaim. Saldo Anda sekarang: " # Nat.toText(updatedProfile.balance);
                return #ok(rewardMessage);
            };
        };
    };

    public shared query func getTask(taskId : Text) : async ?Task {
        return tasks.get(taskId);
    };

    public shared query func getProfile(userId : Text) : async ?UserProfile {
        return userProfiles.get(userId);
    };
};
