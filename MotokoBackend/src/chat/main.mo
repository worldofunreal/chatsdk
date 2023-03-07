import Array     "mo:base/Array";
import Cycles    "mo:base/ExperimentalCycles";
import Error     "mo:base/Error";
import Hash      "mo:base/Hash";
import HashMap   "mo:base/HashMap";
import Int       "mo:base/Int";
import Iter      "mo:base/Iter";
import Nat64     "mo:base/Nat64";
import Prim      "mo:prim";
import Principal "mo:base/Principal";
import Text      "mo:base/Text";
import Time      "mo:base/Time";

import Types "./types";
import GroupCanister "../groups/main";

actor class ChatCore (_owner : Principal) {
    type GroupID        = Types.GroupID;
    type GroupData      = Types.GroupData;
    type UserID         = Types.UserID;
    type Username       = Types.Username;
    type UserData       = Types.UserData;
    type UserGroups     = Types.UserGroups;
    type Friends        = Types.Friends;
    type UserFriendData = Types.UserFriendData;
    type UserSearchData = Types.UserSearchData;
    type UserActivity   = Types.UserActivity;
    
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

    private stable var _userRequestedGroup : [(UserID, [GroupID])] = [];
    var userRequestedGroup : HashMap.HashMap<UserID, [GroupID]> = HashMap.fromIter(_userRequestedGroup.vals(), 0, Principal.equal, Principal.hash);

    private stable var _friendLists : [(UserID, Friends)] = [];
    var friendLists : HashMap.HashMap<UserID, Friends> = HashMap.fromIter(_friendLists.vals(), 0, Principal.equal, Principal.hash);

    private stable var _usersActivity : [(UserID, UserActivity)] = [];
    var usersActivity : HashMap.HashMap<UserID, UserActivity> = HashMap.fromIter(_usersActivity.vals(), 0, Principal.equal, Principal.hash);

    private stable var inited : Bool = false;
    private stable var owner_ : Principal = _owner;
    private stable var groupsCounter : Nat = 1;
    
    //State functions
    system func preupgrade() {
        _groups             := Iter.toArray(groups.entries());
        _users              := Iter.toArray(users.entries());
        _userGroups         := Iter.toArray(userGroups.entries());
        _userRequestedGroup := Iter.toArray(userRequestedGroup.entries());
        _usersActivity      := Iter.toArray(usersActivity.entries());
        _friendLists        := Iter.toArray(friendLists.entries());
    };
    system func postupgrade() {
        _groups             := [];
        _users              := [];
        _userGroups         := [];
        _userRequestedGroup := [];
        _usersActivity      := [];
        _friendLists        := [];
    };
    
    public query func get_user(user : UserID) : async ?UserData{
        return users.get(user);
    };

    public shared query(msg) func get_user_groups() : async [GroupData]{
        switch(userGroups.get(msg.caller)){
            case(null){
                return [];
            };
            case(?_ug){
                var _groupsData : [GroupData] = [];
                for(_g : GroupID in _ug.groups.vals()){
                    switch(groups.get(_g)){
                        case(null){};
                        case(?_gd){
                            _groupsData := Array.append(_groupsData, [_gd]);
                        };
                    };
                };
                return _groupsData;
            };
        };
    };

    public query func getUsername(userID : UserID) : async Username {
        switch(users.get(userID)){
            case(null){
                return Principal.toText(userID);
            };
            case(?_u){
                return _u.username;
            };
        };
        return Principal.toText(userID);
    };

    public shared(msg) func add_user_to_group(groupID : GroupID, user : UserID) : async (Bool, Text){
        switch(groups.get(groupID)){
            case(null){
                return (false, "Group does not exist");
            };
            case(?_gd){
                // assert(_gd.owner == msg.caller); 
                /// (OR msg.caller inside authorized users to add other users OR chat is public) AND user is not banned
                if(_gd.isPrivate == true and _gd.owner != user){
                    let _r : (Bool, Text) = await user_request_join_group(groupID, user);
                    return _r;
                } else {
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
                                groups = [groupID];
                            };
                            userGroups.put(user, ug);
                            return (true, "Success");
                        };
                        case(?_pug){
                            var _ngd : [GroupID] = _pug.groups;
                            _ngd := Array.append(_ngd, [groupID]);
                            let _ugd : UserGroups = {
                                groups = _ngd;
                            };
                            userGroups.put(user, _ugd);
                            return (true, "Success");
                        };
                    };
                };
            };
        };
        return(false, "Request not processed");
    };

    public shared(msg) func remove_user_from_group(user : UserID, groupID : GroupID) : async (Bool, Text){
        switch(groups.get(groupID)){
            case (null){
                return(false, "Invalid Group");
            };
            case(?group){
                let groupCanister : GroupCanister.ChatGroups = actor(group.canister); /// Group canister
                let removed : Bool = await groupCanister.exit_chat(user);
                switch(userGroups.get(user)){
                    case(null){
                        return (false, "User is not added");
                    };
                    case(?_pug){
                        var _ngd : [GroupID] = [];
                        let groupsList = Iter.fromArray(_pug.groups);
                        for(_g : GroupID in groupsList){
                            if(_g != groupID){
                                _ngd := Array.append(_ngd, [_g]);
                            };
                        };
                        let _ugd : UserGroups = {
                            groups = _ngd;
                        };
                        userGroups.put(user, _ugd);
                        return (true, "Success");
                    };
                };
            };
        };
    };

    private func user_request_join_group(groupID : GroupID, userID : UserID) : async (Bool, Text){
        var _requested : (Bool, Text) = (false, "Group does not exists");
        switch(groups.get(groupID)){
            case (null){
                return _requested;
            };
            case (?g){
                let groupCanister : GroupCanister.ChatGroups = actor(g.canister); /// Group canister
                _requested := await groupCanister.user_request_join(userID);
            };
        };
        if(_requested.0 == true or _requested.1 == "User already joined"){
            switch(userRequestedGroup.get(userID)){
                case (null){
                    var _ug : [GroupID] = [];
                    _ug := Array.append(_ug, [groupID]);
                    userRequestedGroup.put(userID, _ug);
                };
                case (?ug){
                    var _ug : [GroupID] = ug;
                    _ug := Array.append(_ug, [groupID]);
                    userRequestedGroup.put(userID, _ug);
                };
            };
            _requested := (true, "User added to the group");
        };
        return _requested;
    };

    public shared query(msg) func hasUserRequestedJoin(groupID : GroupID) : async Bool{
        switch(userRequestedGroup.get(msg.caller)){
            case (null){
                return false;
            };
            case (?_gu){
                for(_group : GroupID in _gu.vals()){
                    if(_group == groupID){
                        return true;
                    };
                };
            };
        };
        return false;
    };

    public shared query(msg) func search_group_by_name(name : Text) : async ?[GroupData] {
        var _gd : [GroupData] = [];
        let x = Text.map(name, Prim.charToLower);
        for(g in groups.vals()){
            if(Text.contains(Text.map(g.name, Prim.charToLower), #text(x)) and g.isDirect == false){
                _gd := Array.append(_gd, [g]);
            };
        };
        return ?_gd;
    };

    public shared query(msg) func is_used_added(idGroup : GroupID, idUser : UserID) : async Bool{
        switch(userGroups.get(idUser)){
            case (null){
                return false;
            };
            case (?ug){
                for(g in ug.groups.vals()){
                    if(g == idGroup){
                        return true;
                    };
                };
                return false;
            };
        };
    };

    public shared(msg) func approveUserPendingGroup(idGroup : GroupID, idUser : UserID) : async (Bool, Text){
        switch(groups.get(idGroup)){
            case(null){
                return (false, "Group does not exist");
            };
            case(?_gd){
                if(_gd.owner == msg.caller){
                    let groupCanister : GroupCanister.ChatGroups = actor(_gd.canister); /// Group canister
                    let _requested : Bool = await groupCanister.hasUserRequestedJoin(idUser);
                    if(_requested == true){
                        let _removedPending : Bool = await groupCanister.approveUserPending(idUser);
                        if(_removedPending == true){
                            switch(users.get(idUser)){
                                case(null){
                                    return (false, "User may not exist");
                                };
                                case(?_ud){
                                    let added : Bool = await groupCanister.join_chat(idUser, _ud);
                                };
                            };
                            switch(userGroups.get(idUser)){
                                case(null){
                                    let ug : UserGroups = {
                                        groups = [idGroup];
                                    };
                                    userGroups.put(idUser, ug);
                                    return (true, "Success");
                                };
                                case(?_pug){
                                    var _ngd : [GroupID] = _pug.groups;
                                    _ngd := Array.append(_ngd, [idGroup]);
                                    let _ugd : UserGroups = {
                                        groups = _ngd;
                                    };
                                    userGroups.put(idUser, _ugd);
                                    return (true, "User successfully approved");
                                };
                            };
                        } else {
                            return (false, "The user is not pending to approve");
                        };
                    } else {
                        return (false, "The user is not pending to approve");
                    };
                } else {
                    return (false, "User not authorized to approve pending users");
                };
            };
        };
    };

    public shared(msg) func rejectUserPendingGroup(idGroup : GroupID, idUser : UserID) : async (Bool, Text){
        switch(groups.get(idGroup)){
            case(null){
                return (false, "Group does not exist");
            };
            case(?_gd){
                if(_gd.owner == msg.caller){
                    let groupCanister : GroupCanister.ChatGroups = actor(_gd.canister); /// Group canister
                    let _requested : Bool = await groupCanister.hasUserRequestedJoin(idUser);
                    if(_requested == true){
                        /// The next function removes the user from the pending list
                        /// Even it's marked as "approve" it doesn't add it in that step
                        let _removedPending : Bool = await groupCanister.approveUserPending(idUser);
                        if(_removedPending == true){
                            return (true, "User rejected from joining group");
                        } else {
                            return (false, "The user is not pending to approve");
                        };
                    } else {
                        return (false, "The user is not pending to approve");
                    };
                } else {
                    return (false, "User not authorized to manage pending users");
                };
            };
        };
    };

    public shared(msg) func create_user_profile(username : Username, description : Text) : async (Bool, Text){
        let _ud : UserData = {
            userID      = msg.caller;
            username    = username;
            description = description;
            avatar      = "";
            banned      = false;
            userSince   = Nat64.fromNat(Int.abs(Time.now()));
        };
        users.put(msg.caller, _ud);
        let _public_group_add : (Bool, Text) = await add_user_to_group(1, msg.caller);
        return _public_group_add;
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
                    userID      = _ud.userID;
                    username    = _ud.username;
                    description = _ud.description;
                    avatar      = _ud.avatar;
                    banned      = true;
                    userSince   = _ud.userSince;
                };
                return true;
            };
        };
    };

    public shared(msg) func initialize() : async Bool{
        assert(msg.caller == owner_ and inited == false);
        let _public_group : GroupData = {
            groupID     = groupsCounter;
            owner       = msg.caller;
            canister    = "yq4sl-yyaaa-aaaag-aaxcq-cai";
            name        = "Public";
            description = "The group for everyone";
            isPrivate   = false;
            isDirect    = false;
            avatar      = "https://cdn-icons-png.flaticon.com/512/4677/4677376.png";
        };
        groups.put(groupsCounter, _public_group);
        groupsCounter += 1;
        inited := true;
        return true;
    };

    public shared(msg) func create_group(_groupname: Text, _isPrivate: Bool, _isDirect : Bool, _description : Text) : async (Bool, Text){
        /// assert user is not banned
        /// assert user has paid for the group
        //Cycles.add(1_000_000_000_000);
        Cycles.add(200_000_000_000);
        let b = await GroupCanister.ChatGroups(msg.caller);
        let _p : ?Principal = ?(Principal.fromActor(b));
        var added : Bool = false;
        switch (_p) {
            case null {
                throw Error.reject("Error creating new group canister");
            };
            case (?groupCanister) {
                let _new_canister_principal : Text = Principal.toText(groupCanister);
                let _grp_can : GroupCanister.ChatGroups = actor(_new_canister_principal);
                switch(users.get(msg.caller)){
                    case(null){
                        return (false, "Not added, user may not exist");
                    };
                    case(?_ud){
                        added := await _grp_can.join_chat(msg.caller, _ud);
                    };
                };
                let _new_group : GroupData = {
                    groupID     = groupsCounter;
                    owner       = msg.caller;
                    canister    = _new_canister_principal;
                    name        = _groupname;
                    isPrivate   = _isPrivate;
                    isDirect    = _isDirect;
                    description = _description;
                    avatar      = "https://www.pngfind.com/pngs/m/670-6709234_people-connection-svg-png-icon-free-download-hub.png";
                };
                groups.put(groupsCounter, _new_group);
                let _public_group_add : (Bool, Text) = await add_user_to_group(groupsCounter, msg.caller);
                groupsCounter += 1;
                return _public_group_add;
            };
        };
        return (true, "OK");
    };

    public shared query(msg) func getPrivateChat(idUser2 : UserID) : async (Nat, Bool){
        var _user1Name : Username = "";
        var _user2Name : Username = "";
        switch(users.get(msg.caller)){
            case(null){
                return (0, false);
            };
            case(?_ud){
                _user1Name := _ud.username;
            };
        };
        switch(users.get(idUser2)){
            case(null){
                return (0, false);
            };
            case(?_ud){
                _user2Name := _ud.username;
            };
        };
        let _groupName1 : Text = _user1Name # " " # _user2Name;
        let _groupName2 : Text = _user2Name # " " # _user1Name;
        for(g in groups.vals()){
            if(g.name == _groupName1 or g.name == _groupName2){
                return (g.groupID, true);
            };
        };
        return (0, true);
    };

    public shared(msg) func create_private_chat(idUser2: UserID) : async (Bool, Text, Nat){
        var _user1Name : Username = "";
        var _user2Name : Username = "";
        let _userCaller = users.get(msg.caller);
        let _user2      = users.get(idUser2);
        switch(_userCaller){
            case(null){
                return (false, "User caller not found", 0);
            };
            case(?_ud){
                _user1Name := _ud.username;
            };
        };
        switch(_user2){
            case(null){
                return (false, "User 2 not found", 0);
            };
            case(?_ud){
                _user2Name := _ud.username;
            };
        };
        let _groupName1 : Text = _user1Name # " " # _user2Name;
        let _groupName2 : Text = _user2Name # " " # _user1Name;
        for(g in groups.vals()){
            if(g.name == _groupName1 or g.name == _groupName2){
                return (false, "Group already exists", g.groupID);
            };
        };
        Cycles.add(200_000_000_000);
        let b = await GroupCanister.ChatGroups(msg.caller);
        let _p : ?Principal = ?(Principal.fromActor(b));
        var added : Bool = false;
        switch (_p) {
            case null {
                throw Error.reject("Error creating new direct chat canister");
            };
            case (?groupCanister) {
                let _new_canister_principal : Text = Principal.toText(groupCanister);
                let _grp_can : GroupCanister.ChatGroups = actor(_new_canister_principal);
                switch(_userCaller){
                    case(null){
                        return (false, "Not added, user caller not found", 0);
                    };
                    case(?_ud){
                        added := await _grp_can.join_chat(msg.caller, _ud);
                    };
                };
                switch(_user2){
                    case(null){
                        return (false, "Not added, user 2 not found", 0);
                    };
                    case(?_ud){
                        added := await _grp_can.join_chat(idUser2, _ud);
                    };
                };
                let _new_group : GroupData = {
                    groupID     = groupsCounter;
                    owner       = msg.caller;
                    canister    = _new_canister_principal;
                    name        = _groupName1;
                    isPrivate   = true;
                    isDirect    = true;
                    description = "Direct chat";
                    avatar      = "https://d1nhio0ox7pgb.cloudfront.net/_img/g_collection_png/standard/512x512/users_relation2.png";
                };
                let _newGroupID : Nat = groupsCounter;
                groups.put(_newGroupID, _new_group);
                switch(userGroups.get(msg.caller)){
                    case(null){
                        let ug : UserGroups = {
                            groups = [_newGroupID];
                        };
                        userGroups.put(msg.caller, ug);
                    };
                    case(?_pug){
                        let _ugd : UserGroups = {
                            groups = Array.append(_pug.groups, [_newGroupID]);
                        };
                        userGroups.put(msg.caller, _ugd);
                    };
                };
                switch(userGroups.get(idUser2)){
                    case(null){
                        let ug : UserGroups = {
                            groups = [_newGroupID];
                        };
                        userGroups.put(idUser2, ug);
                    };
                    case(?_pug){
                        let _ugd : UserGroups = {
                            groups = Array.append(_pug.groups, [_newGroupID]);
                        };
                        userGroups.put(idUser2, _ugd);
                    };
                };
                groupsCounter += 1;
                return (added, "OK", _newGroupID);
            };
        };
        return (false, "GROUP CREATED BUT USERS NOT ADDED", 0);
    };

    public query func getAllUsers() : async [(UserID, UserData)]{
        return Iter.toArray(users.entries());
    };

    public query func getAllGroups() : async [(GroupID, GroupData)]{
        return Iter.toArray(groups.entries());
    };

    public query func getUserGroupsAdmin(user : UserID) : async ?UserGroups {
        userGroups.get(user);
    };

    public func getUserID() : async Principal{
        let _grp_can : GroupCanister.ChatGroups = actor("yq4sl-yyaaa-aaaag-aaxcq-cai");
        await _grp_can.getCaller();
    };

    /*public shared(msg) func set_username(username : Username) : async (Bool, Text){
        assert(msg.caller)
    };*/


    /* GROUPS DATA */
    public shared(msg) func changeGroupName(idGroup : GroupID, newName : Text) : async (Bool, Text) {
        switch(groups.get(idGroup)){
            case(null){
                return (false, "Group does not exist");
            };
            case(?_gd){
                if(_gd.owner == msg.caller){
                    let _newData : GroupData = {
                        groupID     = _gd.groupID;
                        owner       = _gd.owner;
                        canister    = _gd.canister;
                        name        = newName;
                        isPrivate   = _gd.isPrivate;
                        isDirect    = _gd.isDirect;
                        description = _gd.description;
                        avatar      = _gd.avatar;
                    };
                    groups.put(idGroup, _newData);
                    return (true, "Name changed to " # newName);
                } else {
                    return (false, "User not authorized to approve pending users");
                };
            };
        };
    };

    public shared(msg) func changeGroupDescription(idGroup : GroupID, newDescription : Text) : async (Bool, Text) {
        switch(groups.get(idGroup)){
            case(null){
                return (false, "Group does not exist");
            };
            case(?_gd){
                if(_gd.owner == msg.caller){
                    let _newData : GroupData = {
                        groupID     = _gd.groupID;
                        owner       = _gd.owner;
                        canister    = _gd.canister;
                        name        = _gd.name;
                        isPrivate   = _gd.isPrivate;
                        isDirect    = _gd.isDirect;
                        description = newDescription;
                        avatar      = _gd.avatar;
                    };
                    groups.put(idGroup, _newData);
                    return (true, "Description changed");
                } else {
                    return (false, "User not authorized to approve pending users");
                };
            };
        };
    };

    public shared(msg) func changeGroupPrivacy(idGroup : GroupID, newPrivacy : Bool) : async (Bool, Text) {
        switch(groups.get(idGroup)){
            case(null){
                return (false, "Group does not exist");
            };
            case(?_gd){
                if(_gd.owner == msg.caller){
                    let _newData : GroupData = {
                        groupID     = _gd.groupID;
                        owner       = _gd.owner;
                        canister    = _gd.canister;
                        name        = _gd.name;
                        isPrivate   = newPrivacy;
                        isDirect    = _gd.isDirect;
                        description = _gd.description;
                        avatar      = _gd.avatar;
                    };
                    groups.put(idGroup, _newData);
                    return (true, "Privacy changed");
                } else {
                    return (false, "User not authorized to approve pending users");
                };
            };
        };
    };

    public shared(msg) func changeGroupAvatar(idGroup : GroupID, newAvatar : Text) : async (Bool, Text) {
        switch(groups.get(idGroup)){
            case(null){
                return (false, "Group does not exist");
            };
            case(?_gd){
                if(_gd.owner == msg.caller){
                    let _newData : GroupData = {
                        groupID     = _gd.groupID;
                        owner       = _gd.owner;
                        canister    = _gd.canister;
                        name        = _gd.name;
                        isPrivate   = _gd.isPrivate;
                        isDirect    = _gd.isDirect;
                        description = _gd.description;
                        avatar      = newAvatar;
                    };
                    groups.put(idGroup, _newData);
                    return (true, "Privacy changed");
                } else {
                    return (false, "User not authorized to approve pending users");
                };
            };
        };
    };




    /* FRIENDS */
    public shared(msg) func friendRequest(userID : UserID) : async (Bool, Text){
        switch(users.get(userID)){
            case (null){
                /// The user to add does not exists
                return (false, "The user doesn't exists");
            };
            case (?_userData){
                /// var to know if there's need to add or not the request
                var addNew : Bool = false;
                /// Get the caller's friends
                switch(friendLists.get(msg.caller)){
                    case (null){
                        /// User has no friends added yet, add the requested one
                        addNew := true;
                    };
                    case (?userFriends){
                        /// Check if they are already friends
                        for(uf in userFriends.list.vals()){
                            if(userID == uf){
                                return (false, "Already friends");
                            };
                        };
                        // Check if there's already a friend request from the other user
                        for(ur in userFriends.pending.vals()){
                            if(userID == ur){
                                /// User already requested friendship
                                return await addFriend(msg.caller, userID);
                            };
                        };
                        addNew := true;
                    };
                };
                if(addNew == true){
                    /// Add firend request on other user's list
                    switch(friendLists.get(userID)){
                        case(null){
                            /// First friend request
                            let list    : [UserID] = [];
                            var pending : [UserID] = [];
                            pending := Array.append(pending, [msg.caller]);
                            let newUserFriendlist : Friends = {
                                list    = list;
                                pending = pending;
                            };
                            friendLists.put(userID, newUserFriendlist);
                            return (true, "First user request sent");
                        };
                        case(?_ul){
                            let list    : [UserID] = _ul.list;
                            var pending : [UserID] = _ul.pending;
                            pending := Array.append(pending, [msg.caller]);
                            let newUserFriendlist : Friends = {
                                list    = list;
                                pending = pending;
                            };
                            friendLists.put(userID, newUserFriendlist);
                            return (true, "User request sent");
                        };
                    };
                } else {
                    return (false, "Not added");
                };
            };
        };
    };

    public shared query(msg) func getFriendListData () : async ?Friends{
        return friendLists.get(msg.caller);
    };

    public shared(msg) func rejectFriendRequest(userID : UserID) : async (Bool, Text){
        switch(users.get(userID)){
            case (null){
                /// The user to add does not exists
                return (false, "The user doesn't exists");
            };
            case (?_userFriendsList){
                switch(friendLists.get(msg.caller)){
                    case (null){
                        /// User has no friends added yet
                    };
                    case (?userFriends){
                        for(uf in userFriends.list.vals()){
                            if(userID == uf){
                                return (false, "Already friends");
                            };
                        };
                        var _rejected = false;
                        var newRequests : [UserID] = [];
                        var _friends = userFriends.list;
                        for(ur in userFriends.pending.vals()){
                            if(userID == ur){
                                /// User already requested friendship
                                _rejected := true;
                            } else {
                                newRequests := Array.append(newRequests, [ur]);
                            };
                        };
                        if(_rejected == true){
                            let newUserOneFriendlist : Friends = {
                                list    = _friends;
                                pending = newRequests;
                            };
                            friendLists.put(msg.caller, newUserOneFriendlist);
                            return (true, "Friend request rejected");
                        } else {
                            return (false, "Could not reject the request");
                        }
                    };
                };
                return (true, "Friend request rejected");
            };
        };
    };

    private func addFriend(userOne : UserID, userTwo : UserID) : async (Bool, Text){
        /// Add the users for both of them on their friendlist
        switch(friendLists.get(userOne)){
            case (null){
                var _friends : [UserID] = [];
                _friends := Array.append(_friends, [userTwo]);
                var newRequests : [UserID] = [];
                let newUserOneFriendlist : Friends = {
                    list    = _friends;
                    pending = newRequests;
                };
                friendLists.put(userOne, newUserOneFriendlist);
            };
            case (?_userOneFriendlist){
                var _friends = _userOneFriendlist.list;
                _friends := Array.append(_friends, [userTwo]);
                var _requests = _userOneFriendlist.pending;
                var newRequests : [UserID] = [];
                for(ur in _requests.vals()){
                    if(ur != userTwo){
                        newRequests := Array.append(newRequests, [ur]);
                    };
                };
                let newUserOneFriendlist : Friends = {
                    list    = _friends;
                    pending = newRequests;
                };
                friendLists.put(userOne, newUserOneFriendlist);
            };
        };
        switch(friendLists.get(userTwo)){
            case (null){
                var _friends2 : [UserID] = [];
                _friends2 := Array.append(_friends2, [userOne]);
                var newRequests2 : [UserID] = [];
                let newUserTwoFriendlist : Friends = {
                    list    = _friends2;
                    pending = newRequests2;
                };
                friendLists.put(userTwo, newUserTwoFriendlist);
            };
            case (?_userTwoFriendlist){
                var _friends2 = _userTwoFriendlist.list;
                _friends2 := Array.append(_friends2, [userOne]);
                var _requests2 = _userTwoFriendlist.pending;
                var newRequests2 : [UserID] = [];
                for(ur in _requests2.vals()){
                    if(ur != userTwo){
                        newRequests2 := Array.append(newRequests2, [ur]);
                    };
                };
                let newUserTwoFriendlist : Friends = {
                    list    = _friends2;
                    pending = newRequests2;
                };
                friendLists.put(userTwo, newUserTwoFriendlist);
            };
        };
        return (true, "Friends added");
    };

    public shared query(msg) func getMyFriends() : async [UserFriendData]{
        switch(friendLists.get(msg.caller)){
            case (null){
                return [];
            };
            case (?f){
                var uf : [UserFriendData] = [];
                for(f in f.list.vals()){
                    switch(users.get(f)){
                        case(null){};
                        case(?_u){
                            switch(usersActivity.get(_u.userID)){
                                case(null){
                                    let _ufd : UserFriendData = {
                                        userID   = _u.userID;
                                        username = _u.username;
                                        avatar   = _u.avatar;
                                        status   = "Offline";
                                    };
                                    uf := Array.append(uf, [_ufd]);
                                };
                                case(?_a){
                                    let _act : Text = if(_a.offline == true){
                                        "Offline"
                                        } else {
                                            if(_a.define != ""){
                                                _a.define;
                                            } else {
                                                _a.auto;
                                            };
                                        };
                                    let _ufd : UserFriendData = {
                                        userID   = _u.userID;
                                        username = _u.username;
                                        avatar   = _u.avatar;
                                        status   = _act;
                                    };
                                    uf := Array.append(uf, [_ufd]);
                                };
                            }
                        };
                    }
                };
                return uf;
            };
        };
    };

    public shared query(msg) func getMyFriendRequests() : async [UserFriendData]{
        switch(friendLists.get(msg.caller)){
            case (null){
                return [];
            };
            case (?f){
                var uf : [UserFriendData] = [];
                for(f in f.pending.vals()){
                    switch(users.get(f)){
                        case(null){};
                        case(?_u){
                            switch(usersActivity.get(_u.userID)){
                                case(null){
                                    let _ufd : UserFriendData = {
                                        userID   = _u.userID;
                                        username = _u.username;
                                        avatar   = _u.avatar;
                                        status   = "";
                                    };
                                    uf := Array.append(uf, [_ufd]);
                                };
                                case(?_a){
                                    let _act : Text = if(_a.offline == true){
                                        "Offline"
                                        } else {
                                            if(_a.define != ""){
                                                _a.define;
                                            } else {
                                                _a.auto;
                                            };
                                        };
                                    let _ufd : UserFriendData = {
                                        userID   = _u.userID;
                                        username = _u.username;
                                        avatar   = _u.avatar;
                                        status   = _act;
                                    };
                                    uf := Array.append(uf, [_ufd]);
                                };
                            }
                        };
                    }
                };
                return uf;
            };
        };
    };

    public shared query(msg) func getIsFriend(userID : UserID) : async Nat{
        switch(friendLists.get(msg.caller)){
            case (null){
                /// Not friends and not requested from the other user to this user
                switch(friendLists.get(userID)){
                    case(null){
                        return 1;
                    };
                    case(?_r){
                        for(f in _r.pending.vals()){
                        if(f == msg.caller){
                            return 2;
                        };
                    };
                    };
                };
            };
            case (?f){
                for(f in f.list.vals()){
                    if(f == userID){
                        return 3;
                    };
                };
                for(f in f.pending.vals()){
                    if(f == userID){
                        return 2;
                    };
                };
            };
        };
        return 1;
    };

    /* USER'S DATA */
    public shared(msg) func changeUserDescription(newDescription : Text) : async Bool{
        switch(users.get(msg.caller)){
            case(null){
                return false;
            };
            case(?u){
                var _u : UserData = {
                    userID      = u.userID;
                    username    = u.username;
                    description = newDescription;
                    avatar      = u.avatar;
                    banned      = u.banned;
                    userSince   = u.userSince;
                };
                users.put(msg.caller, _u);
                return true;
            };
        };
    };

    public shared(msg) func setImageToUser(img : Text) : async Bool{
        switch(users.get(msg.caller)){
            case(null){
                return false;
            };
            case(?u){
                var _u : UserData = {
                    userID      = u.userID;
                    username    = u.username;
                    description = u.description;
                    avatar      = img;
                    banned      = u.banned;
                    userSince   = u.userSince;
                };
                users.put(msg.caller, _u);
                return true;
            };
        };
    };


    /* USER'S ACTIVITY */
    public shared(msg) func logUserActivity(activity : Text, define : Bool) : async (Bool, Text) {
        var _activity : UserActivity = switch(usersActivity.get(msg.caller)){
            case(null){
                let _a : UserActivity = {
                    auto         = "Online";
                    define       = "";
                    offline      = false;
                    lastActivity = Nat64.fromNat(Int.abs(Time.now()));
                };
            };
            case(?_a){
                _a;
            };
        };
        let _act : UserActivity = if(define == true){
            let _activity2 : UserActivity = {
                auto         = _activity.auto;
                define       = activity;
                offline      = _activity.offline;
                lastActivity = _activity.lastActivity;
            };
        } else {
            let _activity2 : UserActivity = {
                auto         = activity;
                define       = "";
                offline      = _activity.offline;
                lastActivity = _activity.lastActivity;
            };
        };
        usersActivity.put(msg.caller, _act);
        return (true, "OK");
    };

    public query func getUsersActivity(userID : UserID) : async Text{
        switch(usersActivity.get(userID)){
            case(null){
                "Offline";
            };
            case(?a){
                if(a.offline == true){
                    "Offline"
                } else {
                    if(a.define != ""){
                        a.define;
                    } else {
                        a.auto;
                    };
                };
            };
        };
    };


    /* SEARCH USERS */
    public shared query(msg) func search_user_by_name(name : Text) : async ?[UserSearchData] {
        var _ud : [UserSearchData] = [];
        let x = Text.map(name, Prim.charToLower);
        for(u in users.vals()){
            if(Text.contains(Text.map(u.username, Prim.charToLower), #text(x))){
                let _status : Text = switch(usersActivity.get(u.userID)){
                                        case(null){
                                            "Offline";
                                        };
                                        case(?a){
                                            if(a.offline == true){
                                                "Offline"
                                            } else {
                                                if(a.define != ""){
                                                    a.define;
                                                } else {
                                                    a.auto;
                                                };
                                            };
                                        };
                                    };
                let _userFound : UserSearchData = {
                    userID        = u.userID;
                    username      = u.username;
                    avatar        = u.avatar;
                    status        = _status;
                    commonFriends = 0;
                    commonGroups  = 0;
                };
                _ud := Array.append(_ud, [_userFound]);
            };
        };
        return ?_ud;
    };

    public shared(msg) func getUserAvatar(userID : UserID) : async Text{
        switch(users.get(userID)){
            case(null){
                return "";
            };
            case(?u){
                return u.avatar;
            };
        };
    };
};