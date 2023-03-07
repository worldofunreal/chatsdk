import Nat64 "mo:base/Nat64";
module {
    /// Groups
    public type GroupID = Nat;
    public type GroupData = {
        groupID     : GroupID;
        owner       : Principal;
        canister    : Text;
        name        : Text;
        isPrivate   : Bool;
        isDirect    : Bool;
        description : Text;
        avatar      : Text;
    };

    /// Users
    public type UserID   = Principal;
    public type Username = Text;
    public type UserData = {
        userID      : UserID;
        username    : Username;
        description : Text;
        avatar      : Text;
        banned      : Bool;
        userSince   : Nat64;
    };
    public type FullUserData = {
        userID    : UserID;
        username  : Username;
        banned    : Bool;
        avatar    : Text;
        role      : Nat;
        userSince : Nat64;
    };
    public type UserFriendData = {
        userID   : UserID;
        username : Username;
        avatar   : Text;
        status   : Text;
    };
    public type UserSearchData = {
        userID        : UserID;
        username      : Username;
        avatar        : Text;
        status        : Text;
        commonFriends : Nat;
        commonGroups  : Nat;
    };
    public type UserGroups = {
        groups : [GroupID];
    };
    public type RequestJoinData = {
        userID        : UserID;
        dateRequested : Nat64;
        seenByAdmin   : Bool;
    };
    public type UserRoles = {
        #owner;
        #admin;
        #user;
        #banned;
        #nouser;
    };
    public type Friends = {
        list    : [UserID];
        pending : [UserID];
    };
    public type UserActivity = {
        auto         : Text;
        define       : Text;
        offline      : Bool;
        lastActivity : Nat64;
    };
    
    /// Messages
    public type MessageID   = Nat;
    public type MessageData = {
        text     : Text;
        time     : Nat64;
        userID   : UserID;
        username : Username;
    };
    
    /// Private Chats
    public type UserPrivateChats = {
        userID : UserID;
        chatID : Nat32;
    };

}