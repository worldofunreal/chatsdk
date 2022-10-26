# chatsdk
Chat SDK for the Internet Computer 
World of Unreal

## Introduction
Core Idea: For Users
A chat system inside the Internet Computer Blockchain where users can:
* Jump in a public community chat
* Have groups (clans) with private chats
* Have a friend list
* Private chats with friends
* User’s current activity

Core Idea: For Developers
Internet Computer Developers, Web Developers and Unity Developers can easily integrate a chat inside their projects.
* IC Devs can use the canisters calls to interact with the chats that each user has access to.
* Web Devs can integrate the functions to add the chat system inside their projects.
* Unity Devs (Currently only WebGL exports) can integrate the chat inside their games.

The chat code is conformed from 3 modules:
* Canister (backend)
* ReactJS (Frontend)
* Unity3D (Frontend)

## Pre-requisites:
To connect Unity3D and ReactJS we use the react-unity-webgl package, more info on this package can be found here:
[https://react-unity-webgl.dev/docs/8.x.x/introduction](https://react-unity-webgl.dev/docs/8.x.x/introduction)

On Unity3D we are using version 2021.3.11f1 LTS.
For react-unity-webgl we are using version 8.8.0 LTS which has support for Unity 2021.

The following NPM packages installed on your ReactJS project:
@dfinity/agent
ic-stoic-identity /// For Stoic Identity, you can use any of your preference

# Integrate the Chat
## Unity3D Module
On Unity3D you need to import the Chat Module which contains all functions to connect and interact with the Chat SDK.
Inside this module you could change the visual aspect and set the flow to your preference.

## Internet Computer Modules
The first requirement is to add the 2 subfolders found here to your React project
[https://github.com/WorldOfUnreal/chatsdk/tree/main/ReactFrontend/src/canisters](https://github.com/WorldOfUnreal/chatsdk/tree/main/ReactFrontend/src/canisters)

These subfolders contain the canister’s data required to connect to them, one for the core logic and the other for the group’s core logic.
You should not move any code inside this as it can break the correct functionality in your integration.

## React Module
Import both idlFactory files from each canister and also import the following packages (previously installed)
```
import { StoicIdentity } from "ic-stoic-identity";
import { Actor, HttpAgent } from "@dfinity/agent";
import { idlFactory as coreCanisterIDL } from './canisters/core';
import { idlFactory as chatCanisterIDL } from './canisters/public_group';
```
**Please make sure you locate the idlFactory imports correctly according to your directory routing**

### Initialize the data
You’ll need to add the following variables and functions to your project:
```
const [identity,         setIdentity]         = useState(null); /// An identity of the user logged in
const [chatCoreCanister, setChatCoreCanister] = useState(null); /// The canister of the chat
const [userGroups,       setUserGroups]       = useState(null); /// The user's groups list
const [chatSelected,     setChatSelected]     = useState(null); /// The chat selected
const [chatCanister,     setChatCanister]     = useState(null); /// The canister of the selected chat
const [chatText,         setChatText]         = useState(null); /// The text in the selected chat

const host = 'https://raw.ic0.app/'; /// The IC's host URL
const coreCanisterId = "2nfjo-7iaaa-aaaag-qawaq-cai"; /// The Chat canisterId
```

### Process of connecting
A function to receive the request to connect from Unity3D and initialize the process
```
unityContext.on("Login", () => { loginStoic(); });
```

**The identity is required as only logged users can interact with the Chat**

We get the identity and put it on the previously set variable
More information on the process of getting the Stoic Identity here:
[https://github.com/Toniq-Labs/stoic-identity](https://github.com/Toniq-Labs/stoic-identity)

```
// STOIC IDENTITY
const loginStoic = async () => {
  let _stoicIdentity = await StoicIdentity.load().then(async identity => {
    if (identity !== false) {
      //ID is a already connected wallet!
    } else {
      //No existing connection, lets make one!
      identity = await StoicIdentity.connect();
    }
    return identity;
  });
  setIdentity(_stoicIdentity);
};
```

After we have the identity we can set the canister
```
useEffect(() => {
  if(identity !== null) {
    /// When an identity is set, get the Chat canister
    setCoreCanister();
  }
}, [identity]);

const setCanister = async (idl, canisterId) => {
  const _canister = Actor.createActor(idl, {
    agent: new HttpAgent({
      host: host,
      identity,
    }),
    canisterId,
  });
  return _canister;
};

const setCoreCanister = async () => {
    setChatCoreCanister(await setCanister(coreCanisterIDL, coreCanisterId));
};
```

Once we have the canister we can get the user’s data
We need to check if the user exists or is a new user and handle it according to the situation.
If the user already exists, we also need to get the groups it belongs to.
**NOTE: Group on position [0] will always be the public chat on all users**
```
useEffect(() => {
  if(chatCoreCanister !== null){
    /// When the canister is set, get the user's data
    loginUser();
  }
}, [chatCoreCanister]);

const loginUser = async () => {
  /// Get user if exists
  let _user = await chatCoreCanister.get_user(identity.getPrincipal());
  if(_user === null || _user === [] || _user.length <= 0){
    /// Create new user, send request to ask for user's name from Unity
    unityContext.send("ChatManager", "SetNewUser", "");
  } else {
    /// Already created, set the data and get the user's groups
    let _userGroups = await chatCoreCanister.get_user_groups();
    setUserGroups(_userGroups[0].groups);
    let _publicChat = _userGroups[0].groups[0]
    setChatSelected(_publicChat);
    unityContext.send("ChatManager", "Initialize", "");
  }
};
```

If the user is new:
We send a request from React to Unity3D to ask for the new username
```
unityContext.send("ChatManager", "SetNewUser", "");
```

On Unity3D we get the user’s input for the new username and send it back to React
On React we receive the username and create the user on IC with it’s data (identity and username)
```
const createNewUser = async (name) => {
  if(name.trim() === ""){
    alert("Select a valid username");
    return false;
  }
  let _newUser = await chatCoreCanister.create_user_profile(name);
  loginUser();
};
```

Once the user is logged in and we have it’s groups we can get the data from any group, on initialization we get it from the public chat
To get it’s data we need to initialize the canister, set it to the selected canister and call it to get the messages
```
useEffect(() => {
  if(chatSelected !== null){
    /// When the user selects a group, get it's data
    getChatData();
  }
}, [chatSelected]);

const getChatData = async () => {
  let _chatCanister = await setCanister(chatCanisterIDL, chatSelected.canister);
  setChatCanister(_chatCanister);
  let _chatData = await _chatCanister.get_messages();
  setChatText(_chatData);
};
```

Once we have the data we can send to Unity the messages
```
useEffect(() => {
    if(chatText !== null){
      /// Send the messages to Unity
      renderChatMessages();
    }
}, [chatText]);

const renderChatMessages = () => {
  let _chatText = chatText;
  _chatText.sort((a, b) => { return (parseInt(a[0]) - parseInt(b[0])) });
  let _msgUnity = [];
  for(let i = 0; i < _chatText.length; i++){
    let _msg = {
      id:   parseInt(_chatText[i][0]),
      text: _chatText[i][1].username + ": " + _chatText[i][1].text
    };
    _msgUnity.push(_msg);
  }
  _msgUnity = "{\"data\":" + JSON.stringify(_msgUnity) + "}";
  unityContext.send("ChatManager", "GetChatMessages", _msgUnity);
};
```

We structure the messages to show them in a very simple way where the username is on the left and the message on the right.
The idea is for every developer to display it on the way they like more, with their custom styles and order.

From React to Unity3D messages are sent in a json with the following structure:
```
{
  "data":[
    {
      "id": 1,
      "text": "Some text"
    },
    {
      "id": 2,
      "text": "Other text"
    }
  ]
}
```


Once we have all User's data we can get the user's groups to display them on Unity
````
const getUserGroups = async () => {
  let _userGroups = await chatCoreCanister.get_user_groups();
  setUserGroups(_userGroups[0].groups);
  setTimeout(() => {
    getUserGroups();
  }, 5000);
};

const renderGroupsList = () => {
  /// Once we have all user's groups we can display them
  let _userGroups = userGroups;
  /// First we sort them by ID asc
  _userGroups.sort((a, b) => { return (parseInt(a.groupID) - parseInt(b.groupID)) });
  let _groupsUnity = [];
  /// Then we prepare the data for Unity3D
  /// The data needs to be on an array and each registry needs to have id and name
  for(let i = 0; i < _userGroups.length; i++){
    let _group = {
      id:   parseInt(_userGroups[i].groupID),
      name: _userGroups[i].name
    };
    _groupsUnity.push(_group);
  }
  /// After we have the array, it needs to be encapsuled into another json to be processed inside Unity3D
  _groupsUnity = "{\"data\":" + JSON.stringify(_groupsUnity) + "}";
  unityContext.send("ChatManager", "GetGroups", _groupsUnity);
  /// After all data has been send, we set a timeout to continue to query new data
  setTimeout(() => {
    updateChatData();
  }, 3000);
};
````

To select a new group we get from Unity the GroupID requested and set it as selected on React
````
const selectChat = async (groupID) => {
  for(let i = 0; i < userGroups.length; i++){
    console.log(userGroups[i]);
    if(parseInt(userGroups[i].groupID) === groupID){
      setChatSelected(userGroups[i]);
      return true;
    }
  }
  return false;
};
````



On Unity we receive the messages, parse them into the Messages class and add them to the full list


## Sending messages to blockchain
On Unity we get the user’s input and send it to React
And on React we receive it and add it to the group’s chat
```
unityContext.on("SendMessage", (text) => {
    sendMessage(text);
});

const sendMessage = async (message) => {
    if(message.trim() !== ""){
      let _send = await chatCanister.add_text_message(message);
      updateChatData();
    }
};
```

After sending the message we refresh the messages and send them back to Unity3D
```
const updateChatData = async () => {
    let _chatData = await chatCanister.get_messages();
    setChatText(_chatData);
};
```