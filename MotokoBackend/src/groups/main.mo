import Array "mo:base/Array";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Principal "mo:base/Principal";

import Types "../chat/types";

actor class ChatGroups (_owner : Principal) {
    type UserID      = Types.UserID;
    type UserData    = Types.UserData;
    type Username    = Types.Username;
    type MessageID   = Types.MessageID;
    type MessageData = Types.MessageData;

    /// Functions for finding Principals
    func _principalEqual (a : Principal, b : Principal) : Bool {
        return a == b;
    };
    func _principalHash (a : Principal) : Hash.Hash {
        return Principal.hash(a);
    };
    /// Functions for finding Nats
    func _natEqual (a : Nat, b : Nat) : Bool {
        return a == b;
    };
    func _natHash (a : Nat) : Hash.Hash {
        return Hash.hash(a);
    };

    private stable var _users : [(UserID, UserData)] = [];
    var users : HashMap.HashMap<UserID, UserData> = HashMap.fromIter(_users.vals(), 0, _principalEqual, _principalHash);

    private stable var _messages : [(MessageID, MessageData)] = [];
    var messages : HashMap.HashMap<MessageID, MessageData> = HashMap.fromIter(_messages.vals(), 0, _natEqual, _natHash);

    private stable var owner_: Principal = _owner;
    private stable var message_counter : MessageID = 0;

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

    public query func get_group_users() : async [(UserID, UserData)]{
        return Iter.toArray(users.entries());
    };

    public shared(msg) func join_chat(user : UserID, userD : UserData) : async Bool{
        users.put(user, userD);
        return true;
    };

    public shared(msg) func add_text_message(_text : Text) : async Bool{
        let _time        : Nat32 = 0;
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
};