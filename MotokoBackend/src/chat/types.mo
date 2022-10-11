module {
    /// Groups
    public type GroupID = Nat;
    public type GroupData = {
        groupID   : GroupID;
        owner     : Principal;
        canister  : Text;
        name      : Text;
        isPrivate : Bool;
        isDirect  : Bool;
    };

    /// Users
    public type UserID   = Principal;
    public type Username = Text;
    public type UserData = {
        userID   : UserID;
        username : Username;
        banned   : Bool;
    };
    public type UserGroups = {
        groups : [GroupData];
    };
    
    /// Messages
    public type MessageID   = Nat;
    public type MessageData = {
        text     : Text;
        time     : Nat32;
        userID   : UserID;
        username : Username;
    };
}