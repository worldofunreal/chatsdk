using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using System;
using System.Runtime.InteropServices;

//For the InputField to work in WebGL go to Project Settings
// then Go in "Player" Show HTML5/WebGL settings
// Set the Active Input Handling to "Both" instead of "Input System Package (New)"
// if you don't have an EventSystem, create it by right click on Inspector->UI->EventSystem

public class ChatManager : MonoBehaviour
{
    public string username;

    public int maxMessages = 240;
    private int lastMessage = -1;

    public GameObject chatPanel, chatCanvas, textObject, canvasLoginButton, loginPanel, newNamePanel, loadingPanel;
    public InputField chatBox;
    public InputField newUserInput;
    //set the colors in the inspector
    public Color playerMessage, info;

    [Header("Input Settings : ")]
    [SerializeField] private Button loginButton;
    [SerializeField] private Button newUserButton;


    [SerializeField]
    List<Message> messageList = new List<Message>();
    //This doesn't need to be public, no need to have access outside the script

    /// WebGL
    [DllImport("__Internal")]
    private static extern void JSLogin();
    [DllImport("__Internal")]
    private static extern void JSCreateUser(string text);
    [DllImport("__Internal")]
    private static extern void JSSendMessage(string text);

    void Start()
    {
        username = "";
        loginPanel.SetActive(true);
        canvasLoginButton.SetActive(true);
        newNamePanel.SetActive(false);
        loadingPanel.SetActive(false);
        chatCanvas.SetActive(false);
        loginButton.onClick.AddListener (() => { LoginRequest(); });
        newUserButton.onClick.AddListener (() => { CreateUser(); });
    }

    void Update()
    {
        if(chatBox.text != ""){ 
            //Press Enter to send the message to the chatBox
            if(Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter)){
                //SendMessageToChat(username + ": " + chatBox.text, Message.MessageType.playerMessage);
                JSSendMessage(chatBox.text);
                //This is going to reset the chatBox to empty
                chatBox.text = "";
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

    public void GetChatMessages(string json){
        MessagesTexts messagesTexts = JsonUtility.FromJson<MessagesTexts>(json);
        foreach(MessageText m in messagesTexts.data){
            if(lastMessage < m.id){
                SendMessageToChat(m.text,  Message.MessageType.playerMessage);
                lastMessage = m.id;
            }
        }
    }

    public void SendMessageToChat(string text, Message.MessageType messageType)
    {
        {
            //This will clear the last Message after the maximum allowed
            if(messageList.Count >= maxMessages)
            {
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

//For more information on how this script was done check out
// https://www.youtube.com/watch?v=IRAeJgGkjHk
// Thanks to Soupertrooper for this great tutorial