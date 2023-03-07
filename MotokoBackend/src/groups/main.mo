import Array     "mo:base/Array";
import Hash      "mo:base/Hash";
import HashMap   "mo:base/HashMap";
import Int       "mo:base/Int";
import Iter      "mo:base/Iter";
import Nat       "mo:base/Nat";
import Nat64     "mo:base/Nat64";
import Text      "mo:base/Text";
import Time      "mo:base/Time";
import Principal "mo:base/Principal";

import Types "../chat/types";

actor class ChatGroups (_owner : Principal) {
    type UserID          = Types.UserID;
    type UserData        = Types.UserData;
    type Username        = Types.Username;
    type MessageID       = Types.MessageID;
    type MessageData     = Types.MessageData;
    type UserRoles       = Types.UserRoles;
    type RequestJoinData = Types.RequestJoinData;
    type FullUserData    = Types.FullUserData;

    /// Functions for finding Nats
    func _natEqual (a : Nat, b : Nat) : Bool {
        return a == b;
    };
    func _natHash (a : Nat) : Hash.Hash {
        return Hash.hash(a);
    };

    private stable var _users : [(UserID, UserData)] = [];
    var users : HashMap.HashMap<UserID, UserData> = HashMap.fromIter(_users.vals(), 0, Principal.equal, Principal.hash);

    private stable var _messages : [(MessageID, MessageData)] = [];
    var messages : HashMap.HashMap<MessageID, MessageData> = HashMap.fromIter(_messages.vals(), 0, _natEqual, _natHash);

    private stable var _pendingUsers : [(UserID, RequestJoinData)] = [];
    var pendingUsers : HashMap.HashMap<UserID, RequestJoinData> = HashMap.fromIter(_pendingUsers.vals(), 0, Principal.equal, Principal.hash);

    private stable var owner_ : Principal = _owner;
    private stable var message_counter : MessageID = 0;
    private stable var coreCanister    : Principal = Principal.fromText("2nfjo-7iaaa-aaaag-qawaq-cai");

    public query func is_user_added(user : UserID) : async Bool{
        let _u : ?UserData = users.get(user);
        switch(_u){
            case(null){
                return false;
            };
            case(_d){
                return true;
            };
        };
        return false;
    };

    public query func get_group_users() : async [FullUserData]{
        var _arr : [FullUserData] = [];
        for(_user : UserData in users.vals()){
            let _u : FullUserData = {
                userID    = _user.userID;
                username  = _user.username;
                banned    = _user.banned;
                avatar    = _user.avatar;
                role      = getUserRoleIndex(_user.userID);
                userSince = _user.userSince;
            };
            _arr := Array.append(_arr, [_u]);
        };
        return _arr;
    };

    public shared(msg) func join_chat(user : UserID, userD : UserData) : async Bool{
        assert(msg.caller == _owner or msg.caller == coreCanister);
        /// TODO check if user can be added
        users.put(user, userD);
        return true;
    };

    public shared(msg) func user_request_join(userID : UserID) : async (Bool, Text){
        switch(users.get(userID)){
            case(null){
                switch(pendingUsers.get(userID)){
                    case (null){
                        let _request : RequestJoinData = {
                            userID        = userID;
                            dateRequested = Nat64.fromNat(Int.abs(Time.now()));
                            seenByAdmin   = false;
                        };
                        pendingUsers.put(userID, _request);
                        return (true, "Requested successfully");
                    };
                    case (?_){
                        return (false, "User already requested to join");
                    };
                };
            };
            case(?_){
                return (true, "User already joined");
            };
        };
    };

    public shared query(msg) func hasUserRequestedJoin(userID : UserID) : async Bool{
        switch(users.get(userID)){
            case(null){
                switch(pendingUsers.get(userID)){
                    case (null){
                        return false;
                    };
                    case (?_){
                        return true;
                    };
                };
            };
            case(?_){
                return true;
            };
        };
    };

    public shared query(msg) func getUsersPending() : async [RequestJoinData]{
        assert(msg.caller == _owner);
        return Iter.toArray(pendingUsers.vals());
    };

    public shared(msg) func approveUserPending(userID : UserID) : async Bool{
        assert(msg.caller == _owner or msg.caller == coreCanister);
        switch(pendingUsers.remove(userID)){
            case (null){
                return false;
            };
            case (?_){
                return true;
            };
        };
    };

    public shared(msg) func rejectUserPending(userID : UserID) : async Bool{
        assert(msg.caller == _owner);
        switch(pendingUsers.remove(userID)){
            case (null){
                return false;
            };
            case (?_){
                return true;
            };
        };
    };

    public shared query(msg) func getUserRole() : async UserRoles{
        if(msg.caller == owner_){
            return #owner;
        };
        switch(users.get(msg.caller)){
            case(null){
                return #nouser;
            };
            case(?_){
                return #user;
            };
        };
    };

    func getUserRoleIndex(userID : UserID) : Nat {
        if(userID == owner_){
            return 0;
        };
        switch(users.get(userID)){
            case(null){
                return 3;
            };
            case(?_){
                return 2;
            };
        };
    };

    public shared(msg) func exit_chat(user : UserID) : async Bool{
        switch(users.remove(user)){
            case (null){
                return false;
            };
            case (?_){
                return true;
            };
        };
    };

    public shared(msg) func add_text_message(_text : Text) : async Bool{
        /// TODO Check user is added (or chat is public) and not banned
        let _time        : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
        let _username    : Username = await getUsername(msg.caller);
        let _new_message : MessageData = {
            text     = _text;
            time     = _time;
            userID   = msg.caller;
            username = _username;
        };
        messages.put(message_counter, _new_message);
        message_counter := message_counter + 1;
        return true;
    };

    public shared query(msg) func get_messages() : async [(MessageID, MessageData)]{
        /// TODO Check user is added (or chat is public) and not banned
        /// TODO Pagination
        return Iter.toArray(messages.entries());
    };

    public shared query(msg) func get_total_messages() : async MessageID{
        return message_counter;
    };

    func getUsername(user: UserID) : async Username{
        switch(users.get(user)){
            case(null){
                return Principal.toText(user);
            };
            case(?_u){
                return _u.username;
            };
        };
        return Principal.toText(user);
    };

    public shared query(msg) func getCaller() : async Principal{
        msg.caller;
    };

    public shared(msg) func transferOwner(to : UserID) : async (Bool, Text){
        assert(msg.caller == owner_);
        switch(users.get(to)){
            case (null){
                return (false, "User is not in the group");
            };
            case(?_to){
                owner_ := to;
                return(true, "Ownership transferred");
            };
        };
    };
};