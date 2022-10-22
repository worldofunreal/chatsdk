mergeInto(LibraryManager.library, {
  // Create a new function with the same name as
  // the event listeners name and make sure the
  // parameters match as well.

  JSLogin: function () {
    ReactUnityWebGL.Login();
  },

  JSCreateUser: function (username) {
    ReactUnityWebGL.CreateUser(Pointer_stringify(username));
    ///ReactUnityWebGL.SavePlayerConfig(Pointer_stringify(json));
  },

  JSSelectChatGroup: function (idChat) {
    ReactUnityWebGL.SelectChatGroup(idChat);
  },

  JSSendMessage: function (message) {
    ReactUnityWebGL.SendMessage(Pointer_stringify(message));
  },

  JSAddUserToGroup: function (json) {
    ReactUnityWebGL.AddUserToGroup(Pointer_stringify(json));
  },

  JSCreateGroup: function (groupname) {
    ReactUnityWebGL.CreateGroup(Pointer_stringify(groupname));
  },
});