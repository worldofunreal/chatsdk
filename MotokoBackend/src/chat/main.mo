import Array "mo:base/Array";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";

import Types "./types";
import GroupCanister "../groups/main";

actor class ChatCore (_owner : Principal) {
    type GroupID    = Types.GroupID;
    type GroupData  = Types.GroupData;
    type UserID     = Types.UserID;
    type Username   = Types.Username;
    type UserData   = Types.UserData;
    type UserGroups = Types.UserGroups;
    
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

    private stable var _groups : [(GroupID, GroupData)] = [];
    var groups : HashMap.HashMap<GroupID, GroupData> = HashMap.fromIter(_groups.vals(), 0, _natEqual, _natHash);

    private stable var _users : [(UserID, UserData)] = [];
    var users : HashMap.HashMap<UserID, UserData> = HashMap.fromIter(_users.vals(), 0, _principalEqual, _principalHash);

    private stable var _userGroups : [(UserID, UserGroups)] = [];
    var userGroups : HashMap.HashMap<UserID,UserGroups> = HashMap.fromIter(_userGroups.vals(), 0, _principalEqual, _principalHash);    

    private stable var inited : Bool = false;
    private stable var owner_ : Principal = _owner;
    private stable var groupsCounter : Nat = 0;

    public query func get_user(user : UserID) : async ?UserData{
        return users.get(user);
    };

    public shared query(msg) func get_user_groups() : async ?UserGroups{
        return userGroups.get(msg.caller);
    };

    public shared(msg) func add_user_to_group(groupID : GroupID, user : UserID) : async (Bool, Text){
        switch(groups.get(groupID)){
            case(null){
                return (false, "Group does not exist");
            };
            case(?_gd){
                // assert(_gd.owner == msg.caller); 
                /// (OR msg.caller inside authorized users to add other users OR chat is public) AND user is not banned
                
                /// TODO Add user to the canister's group
                let groupCanister : GroupCanister.ChatGroups = actor(_gd.canister); /// Group canister
                let _userData : ?UserData = users.get(user);
                switch(_userData){
                    case(null){
                        return (false, "Not added, user may not exist");
                    };
                    case(?_ud){
                        let added : Bool = await groupCanister.join_chat(user, _ud);
                    };
                };
                switch(userGroups.get(user)){
                    case(null){
                        let ug : UserGroups = {
                            groups = [_gd];
                        };
                        userGroups.put(user, ug);
                        return (true, "Success");
                    };
                    case(?_pug){
                        var _ngd : [GroupData] = _pug.groups;
                        _ngd := Array.append(_ngd, [_gd]);
                        let _ugd : UserGroups = {
                            groups = _ngd;
                        };
                        userGroups.put(user, _ugd);
                        return (true, "Success");
                    };
                };
            };
        };
        return(false, "Request not processed");
    };

    public shared(msg) func create_user_profile(username : Username) : async Bool{
        let _ud : UserData = {
            userID   = msg.caller;
            username = username;
            banned   = false;
        };
        users.put(msg.caller, _ud);
        let _public_group_add : (Bool, Text) = await add_user_to_group(0, msg.caller);
        return true;
    };

    public shared(msg) func ban_user(user : UserID) : async Bool{
        assert(msg.caller == owner_);
        let _u : ?UserData = users.get(user);
        switch(_u){
            case(null){
                return false;
            };
            case(?_ud){
                let _nud : UserData = {
                    userID   = _ud.userID;
                    username = _ud.username;
                    banned   = true;
                };
                return true;
            };
        };
    };

    public shared(msg) func initialize() : async Bool{
        assert(msg.caller == owner_ and inited == false);
        let _public_group : GroupData = {
            groupID   = groupsCounter;
            owner     = msg.caller;
            canister  = "yq4sl-yyaaa-aaaag-aaxcq-cai";
            name      = "Public";
            isPrivate = false;
            isDirect  = false;
        };
        groups.put(groupsCounter, _public_group);
        groupsCounter += 1;
        inited := true;
        return true;
    };

    /*public shared(msg) func set_username(username : Username) : async (Bool, Text){
        assert(msg.caller)
    };*/
};




/*

Normal users:
* Can chat in public group
* Can be added to private groups
* Can chat in private groups added

Premium users:
* All from normal users
* Can create groups as long as its within their quota plan

Premium plans:
*  5 Private group chats +   5 Private friend chats + in-game direct chat
* 10 Private group chats +  25 Private friend chats + in-game direct chat
* 50 Private chats chats + 100 Private friend chats + in-game direct chat

Costs and prices: 
(
 (# of available private chats * costs of a month worth of tokens for cycles ) 
 + 
 (cost of creating a canister in cycles * # of available chats) 
) * 1.03


Additional individual chats = (costs of a month worth of tokens for cycles + cost of creating a canister in cycles) * 1.10

*/