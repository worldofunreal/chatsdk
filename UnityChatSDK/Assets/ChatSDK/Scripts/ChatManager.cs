using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

//For the InputField to work in WebGL go to Project Settings
// then Go in "Player" Show HTML5/WebGL settings
// Set the Active Input Handling to "Both" instead of "Input System Package (New)"
// if you don't have an EventSystem, create it by right click on Inspector->UI->EventSystem

public class ChatManager : MonoBehaviour
{
    public string username;

    public int maxMessages = 24;

    public GameObject chatPanel, textObject;
    public InputField chatBox;
    //set the colors in the inspector
    public Color playerMessage, info;


    [SerializeField]
    List<Message> messageList = new List<Message>();
    //This doesn't need to be public, no need to have access outside the script

    void Start()
    {
        
    }

    void Update()
    {
        if(chatBox.text != "")
        {
            //Press Enter to send the message to the chatBox
           if(Input.GetKeyDown(KeyCode.Return)
           //or
            || Input.GetKeyDown(KeyCode.KeypadEnter))
           {
            SendMessageToChat(username + ": " + chatBox.text, Message.MessageType.playerMessage);
            //This is going to reset the chatBox to empty
            chatBox.text = "";
           }
        }

        else
        {
            //if the chatBox is !not focused, it can 
            if(!chatBox.isFocused && Input.GetKeyDown(KeyCode.Return))
                chatBox.ActivateInputField();
                //still needs code to deactivate with another enter
        }
        
        // this is for actions when the chat is focused
        if(chatBox.isFocused)
            
        {
            //Debug logs
             if(Input.GetKeyDown(KeyCode.Space))
                {
                     SendMessageToChat("You pressed the space bar!",
                     Message.MessageType.info);
                      Debug.Log("Space");
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


//For more information on how this script was done check out
// https://www.youtube.com/watch?v=IRAeJgGkjHk
// Thanks to Soupertrooper for this great tutorial