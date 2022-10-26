using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using static UnityEngine.UI.Text;
using System;
using System.Runtime.InteropServices;
using TMPro;

//For the InputField to work in WebGL go to Project Settings
// then Go in "Player" Show HTML5/WebGL settings
// Set the Active Input Handling to "Both" instead of "Input System Package (New)"
// if you don't have an EventSystem, create it by right click on Inspector->UI->EventSystem

public class ChatManager : MonoBehaviour
{
    public string username;

    public int maxMessages = 240;
    private int lastMessage = -1;
    public int idGroupSelected = 0;
    [SerializeField] float itemSpacing = .5f;

    private string pasteTxt = "";

    public GameObject chatPanel, chatCanvas, textObject, canvasLoginButton, loginPanel, newNamePanel, loadingPanel;
    public InputField chatBox;
    public InputField newUserInput;
    //set the colors in the inspector
    public Color playerMessage, info;

    [Header("Side Panel : ")]
    public GameObject sidePanel;
    [SerializeField] private Button addButton;
    public GameObject popupPanel, addQuestionPanel, addGroupPanel, addUserPanel, groupObject;
    [SerializeField] private Button addGroupOptionButton;
    [SerializeField] private Button newGroupButton;
    public InputField newGroupInput;
    [SerializeField] private Button addUserToGroupOptionButton;
    [SerializeField] private Button addUserToGroupButton;
    public InputField addUserToGroupInput;
    [SerializeField] private Button closePopupButton;
    [SerializeField] private Button returnToPopup1;
    [SerializeField] private Button returnToPopup2;
    private bool openAddPopup = false;

    [Header("Input Settings : ")]
    [SerializeField] private Button loginButton;
    [SerializeField] private Button newUserButton;


    [SerializeField]
    List<Message> messageList = new List<Message>();
    //This doesn't need to be public, no need to have access outside the script

    [SerializeField]
    List<Group> groupsList = new List<Group>();

    /// WebGL
    [DllImport("__Internal")]
    private static extern void JSLogin();
    [DllImport("__Internal")]
    private static extern void JSCreateUser(string text);
    [DllImport("__Internal")]
    private static extern void JSSendMessage(string text);
    [DllImport("__Internal")]
    private static extern void JSAddUserToGroup(string json);
    [DllImport("__Internal")]
    private static extern void JSCreateGroup(string text);
    [DllImport("__Internal")]
    private static extern void JSSelectChatGroup(int id);

    void Start()
    {
        username = "";
        loginPanel.SetActive(true);
        canvasLoginButton.SetActive(true);
        newNamePanel.SetActive(false);
        loadingPanel.SetActive(false);
        chatCanvas.SetActive(false);
        popupPanel.SetActive(false);
        loginButton.onClick.AddListener (() => { LoginRequest(); });
        newUserButton.onClick.AddListener (() => { CreateUser(); });
        addButton.onClick.AddListener(() => { ToggleAddPopup(); });
        addGroupOptionButton.onClick.AddListener(() => { GroupOptionButton(); });
        newGroupButton.onClick.AddListener(() => { CreateGroup(); });
        addUserToGroupOptionButton.onClick.AddListener(() => { AddUserToGroupOptionButton(); });
        addUserToGroupButton.onClick.AddListener(() => { AddUserToGroupButton(); });
        /// Popup -> Return
        closePopupButton.onClick.AddListener(() => { ToggleAddPopup(); });
        returnToPopup1.onClick.AddListener(() => { returnToPopup(); });
        returnToPopup2.onClick.AddListener(() => { returnToPopup(); });
    }

    void Update()
    {
        if(openAddPopup == false){
            if(chatBox.text != ""){ 
                //Press Enter to send the message to the chatBox
                if(Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter)){
                    //SendMessageToChat(username + ": " + chatBox.text, Message.MessageType.playerMessage);
                    JSSendMessage(chatBox.text);
                    //This is going to reset the chatBox to empty
                    chatBox.text = "";
                    /// Close the New Popup
                    popupPanel.SetActive(false);
                    openAddPopup = false;
                }
            } else {
                //if the chatBox is !not focused, it can 
                if(!chatBox.isFocused && (Input.GetKeyDown("t") || Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter))){
                    chatBox.ActivateInputField();
                    //still needs code to deactivate with another enter
                }
            }
            if(chatBox.isFocused && Input.GetKeyDown(KeyCode.Escape)){
                //chatBox.ActivateInputField();
                //still needs code to deactivate with another enter
            }
        }

        if(pasteTxt != ""){
            if(chatBox.isFocused == true){
                /// Chat input
                chatBox.text = pasteTxt;
                pasteTxt = "";
            } else {
                if(newGroupInput.isFocused == true){
                    /// Create group
                    newGroupInput.text = pasteTxt;
                    pasteTxt = "";
                } else {
                    if(addUserToGroupInput.isFocused == true){
                        /// Add user to group
                        addUserToGroupInput.text = pasteTxt;
                        pasteTxt = "";
                    } else {
                        if(newUserInput.isFocused == true){
                            /// Create user
                            newUserInput.text = pasteTxt;
                            pasteTxt = "";
                        }
                    }
                }
            }
        }
    }

    private void LoginRequest(){
        JSLogin();
        loadingPanel.SetActive(true);
        canvasLoginButton.SetActive(false);
    }

    public void SetNewUser(){
        loadingPanel.SetActive(false);
        newNamePanel.SetActive(true);
    }

    public void CreateUser(){
        if(newUserInput.text != ""){
            JSCreateUser(newUserInput.text);
            username = newUserInput.text;
            loadingPanel.SetActive(true);
            newNamePanel.SetActive(false);
        } else {
            newUserInput.ActivateInputField();
        }
    }

    public void Initialize(){
        loadingPanel.SetActive(false);
        loginPanel.SetActive(false);
        chatCanvas.SetActive(true);
    }

    public void SendMessageToBlockchain(string text){
        if(text != ""){
            JSSendMessage(text);
        }
    }

    public void ClearMessages(){
        for(int i = 0; i < messageList.Count; i++) {
            Destroy(messageList[i].textObject.gameObject);
        }
        messageList.Clear();
        lastMessage = -1;
    }

    public void GetChatMessages(string json){
        MessagesTexts messagesTexts = JsonUtility.FromJson<MessagesTexts>(json);
        foreach(MessageText m in messagesTexts.data){
            if(lastMessage < m.id){
                SendMessageToChat(m.text,  Message.MessageType.playerMessage);
                lastMessage = m.id;
            }
        }
    }

    public void SendMessageToChat(string text, Message.MessageType messageType) {
        //This will clear the last Message after the maximum allowed
        if(messageList.Count >= maxMessages) {
            //This is to destroy only the text, but not the Object
            Destroy(messageList[0].textObject.gameObject);
            messageList.Remove(messageList[0]);
        }

        //This is to add the Message to the list and keep track of it
        Message newMessage = new Message();
        newMessage.text = text;

        //Create a new game object to instantiate the text Prefab for new Messages
        GameObject newText = Instantiate(textObject, chatPanel.transform);
        newMessage.textObject = newText.GetComponent<Text>();
        newMessage.textObject.text = newMessage.text;
        newMessage.textObject.color = MessageTypeColor(messageType);
        messageList.Add(newMessage);
    }

    public void GetGroups(string json){
        //groupsList.Clear();
        GroupsList _groupsList = JsonUtility.FromJson<GroupsList>(json);
        int i = 0;
        foreach(GroupData g in _groupsList.data){
            AddGroupToList(g.id, g.name, i);
            i++;
        }
    }

    public void AddGroupToList(int id, string name, int i){
        Group g = new Group();
        g.id    = id;
        g.name  = name;
        GameObject newGroup = Instantiate(groupObject, sidePanel.transform);
        Vector3 temp = new Vector3(0,i * (125.0f + itemSpacing),0);
        newGroup.transform.position -= temp;
        Button btn = newGroup.GetComponent<Button>();
		btn.onClick.AddListener(() => { SetGroupSelected(id); });
        TextMeshProUGUI btnTxt = btn.GetComponentInChildren<TextMeshProUGUI>();
        if(btnTxt != null){
            btnTxt.text = name;
        }
        groupsList.Add(g);
    }

    public void SetGroupSelected(int id){
        idGroupSelected = id;
        JSSelectChatGroup(id);
    }

    public void ToggleAddPopup(){
        if(openAddPopup == false){
            returnToPopup();
            openAddPopup = true;
            popupPanel.SetActive(true);
        } else {
            openAddPopup = false;
            popupPanel.SetActive(false);
        }
    }

    public void returnToPopup(){
        addQuestionPanel.SetActive(true);
        addGroupPanel.SetActive(false);
        addUserPanel.SetActive(false);
    }

    public void GroupOptionButton(){
        addQuestionPanel.SetActive(false);
        addGroupPanel.SetActive(true);
        addUserPanel.SetActive(false);
    }

    public void AddUserToGroupOptionButton(){
        addQuestionPanel.SetActive(false);
        addGroupPanel.SetActive(false);
        addUserPanel.SetActive(true);
    }

    public void AddUserToGroupButton(){
        /// Add new user to currently selected group
        if(addUserToGroupInput.text != ""){
            string jsn = "{\"userId\":\"" + addUserToGroupInput.text + "\", \"groupId\": " + idGroupSelected + "}" ;
            Debug.Log("Add user");
            Debug.Log(jsn);
            JSAddUserToGroup(jsn);
        }
    }

    public void CreateGroup(){
        if(newGroupInput.text != ""){
            JSCreateGroup(newGroupInput.text);
        }
    }

    public void getPaste(string s){
        pasteTxt = s;
    }

    public void UserAdded(bool result){
        if(result == true){
            ToggleAddPopup();
        } else {
            ToggleAddPopup();
        }
    }

    Color MessageTypeColor(Message.MessageType messageType)
    {
        Color color = info;
        //check on different cases
        switch(messageType)
        {
            //you can have many different cases instead of "playerMessage"
            case Message.MessageType.playerMessage:
            color = playerMessage;
            break;
            //its an if statement where you 
            //check against one variable that can be set
            //to be many different things 
            //this can also be used for ints and floats
        }

        return color;
    }
}

[System.Serializable]
public class Message
{
    //this is the Serializable string of the Message
    public string text;
    public Text textObject;
    public MessageType messageType;

    public enum MessageType
    {
        playerMessage,
        info
    }
}

[System.Serializable]
public class MessageText {
    public int id;
    public string text;
}
[System.Serializable]
public class MessagesTexts {
    public List<MessageText> data;
}

[System.Serializable]
public class Group{
    public int id;
    public string name;
    public Button groupObject;
}
[System.Serializable]
public class GroupData{
    public int id;
    public string name;
}
[System.Serializable]
public class GroupsList{
    public List<GroupData> data;
}

//For more information on how this script was done check out
// https://www.youtube.com/watch?v=IRAeJgGkjHk
// Thanks to Soupertrooper for this great tutorial