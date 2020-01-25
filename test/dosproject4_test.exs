defmodule Dosproject4Test do
  use ExUnit.Case
  # doctest Dosproject4
  setup_all do
    Registry.start_link(keys: :unique, name: :twitterRegistry)
    TwitterServer.start_link()
    :ok
  end

  test "User Registration" do
    # 3 users registered and checked if only 3 users are present in server
    # Test Case passed
    users = ["user1","user2","user3"]
    Enum.each(users, fn(x) -> {:ok,clientId} = TwitterClient.start_link(x)
                                GenServer.call(clientId,{:registerUser,x,"password"})
                              end)
    :timer.sleep(100)
    list = Enum.map(users, fn x-> :ets.lookup(:userList,x) end)
    assert length(list)==length(users)
  end

  test "User Deletion" do
    # 2 users created and 1 deleted - so only one remains in the server among the two.
    # Test cases passed
    users = ["user6","user7"]
    Enum.each(users, fn(x) -> {:ok,clientId} = TwitterClient.start_link(x)
                                GenServer.call(clientId,{:registerUser,x,"password"})
                              end)
    deletedClient = elem(hd(Registry.lookup(:twitterRegistry, "user7")),0)
    GenServer.call(deletedClient,{:deleteUser})
    list = Enum.map(users, fn x-> :ets.lookup(:userList,x) end)|>List.flatten()
    assert length(list)==1
  end

  test "User login correct details test" do
    # one user is created
    # logged in with correct details - output should be it's present in activeusers
    # Test cases passed
    user = "user4"
    {:ok,clientID} = TwitterClient.start_link(user)
    GenServer.call(clientID,{:registerUser,user,"password"})
    GenServer.call(clientID, {:loginUser, user, "password"})
    val = Enum.member?(:ets.lookup(:activeUser,user),{user})
    assert  val == true
  end

  test "User login incorrect details test" do
    # one user is created
    # logged in with incorrect details - output should be it's not present in activeusers
    # Test cases passed
    IO.inspect("Testing user login with wrong details")
    user = "user5"
    {:ok,clientID} = TwitterClient.start_link(user)
    GenServer.call(clientID,{:registerUser,user,"password"})
    GenServer.call(clientID, {:loginUser, user, "pwd"})
    val = Enum.member?(:ets.lookup(:activeUser,user),{user})
    assert  val == false
  end

  test "User logout" do
    # one user is created
    # logged out from the user and hence won't be present in active user list
    # Test cases passed
    user = "user8"
    {:ok,clientID} = TwitterClient.start_link(user)
    GenServer.call(clientID,{:registerUser,user,"password"})
    GenServer.call(clientID, {:loginUser, user, "password"})
    :timer.sleep(10)
    GenServer.call(clientID, {:logoutUser})
    val = Enum.member?(:ets.lookup(:activeUser,user),{user})
    assert  val == false
  end

  test "User subscribing and following" do
    # 2 users are created
    # user9 subscribes to user10
    # Test cases passed
    users = ["user9","user10"] 
    Enum.each(users, fn(x) -> {:ok,clientId} = TwitterClient.start_link(x)
                                GenServer.call(clientId,{:registerUser,x,"password"})
                              end)
    subscribingClient = elem(hd(Registry.lookup(:twitterRegistry, "user9")),0)
    GenServer.cast(subscribingClient,{:subscribe, "user10"})
    :timer.sleep(100)
    [{_,subscribingList}] = :ets.lookup(:subscribedTo,"user9")
    [{_,followersList}] = :ets.lookup(:followers,"user10")
    assert Enum.member?(subscribingList,"user10") == true and Enum.member?(followersList,"user9") == true
  end

  test "User tweets stored" do
    # 1 user is created
    # user sends 3 tweets and the value is checked in the tweets table if 3 tweets are present for this user
    # Test cases passed
    user = "user11"
    {:ok,clientID} = TwitterClient.start_link(user)
    GenServer.call(clientID,{:registerUser,user,"password"})
    GenServer.call(clientID, {:loginUser, user, "password"})
    tw1 = "user11 tweet1"
    tw2 = "user11 tweet2"
    tw3 = "user11 tweet3"
    GenServer.cast(clientID,{:tweet,tw1})
    GenServer.cast(clientID,{:tweet,tw2})
    GenServer.cast(clientID,{:tweet,tw3})
    :timer.sleep(30)
    [{_,l}] = :ets.lookup(:tweets,"user11")
    assert length(l) == 3
  end

  test "Hashtag query" do
    # 1 user is created and sends 3 tweets with one hashtag 
    # when queried with the hastag, we check if there are 3 tweets
    # Test cases passed
    
    user = "user12"
    {:ok,clientID} = TwitterClient.start_link(user)
    GenServer.call(clientID,{:registerUser,user,"password"})
    GenServer.call(clientID, {:loginUser, user, "password"})
    tw1 = "tweet1 #abcd"
    tw2 = "tweet2 #abcd"
    tw3 = "tweet3 #def"
    GenServer.cast(clientID,{:tweet,tw1})
    GenServer.cast(clientID,{:tweet,tw2})
    GenServer.cast(clientID,{:tweet,tw3})
    :timer.sleep(30)
    ht1 = GenServer.call(clientID,{:queryHashtags, "#abcd"})
    ht2 = GenServer.call(clientID,{:queryHashtags, "#def"})
    assert length(ht1) == 2 and length(ht2) == 1
  end

  test "User Mentions query" do
    # 2 users are created
    # one user tweets 2 tweets with another user mentioned
    # the tweet is present in both mentions table and feed of the mentioned user
    # Test cases passed

    users = ["user13","user14"]
    Enum.each(users, fn(x) -> {:ok,clientId} = TwitterClient.start_link(x)
                                GenServer.call(clientId,{:registerUser,x,"password"})
                                GenServer.call(clientId, {:loginUser, x, "password"})
                              end)
    tw1 = "tweet1 @user14 mentions"
    tw2 = "tweet2 @user14 mentions"
    clientID = elem(hd(Registry.lookup(:twitterRegistry, "user13")),0)
    mentionedClientId = elem(hd(Registry.lookup(:twitterRegistry, "user14")),0)
    GenServer.cast(clientID,{:tweet,tw1})
    GenServer.cast(clientID,{:tweet,tw2})
    :timer.sleep(200)
    mentionedTweets = GenServer.call(mentionedClientId,{:queryMentions})
    # IO.inspect(mentionedTweets)
    livefeed = GenServer.call(mentionedClientId,{:liveFeed})
    # IO.inspect(livefeed)
    assert length(mentionedTweets) == 2 and length(livefeed) == 2
  end

  test "User tweets live online followers" do
    # 2 users are created where the followers of user are active
    # the active user receives the tweet in his feed
    # Test cases passed
    users = ["user15","user16"]
    Enum.each(users, fn(x) -> {:ok,clientId} = TwitterClient.start_link(x)
                                GenServer.call(clientId,{:registerUser,x,"password"})
                                GenServer.call(clientId, {:loginUser, x, "password"})
                              end)
    tw1 = "user15 tweet1"
    tw2 = "user15 tweet2"
    tw3 = "user15 tweet3"
    clientID = elem(hd(Registry.lookup(:twitterRegistry, "user15")),0)
    liveFollower = elem(hd(Registry.lookup(:twitterRegistry, "user16")),0)
    GenServer.cast(liveFollower,{:subscribe, "user15"})
    :timer.sleep(100)
    GenServer.cast(clientID,{:tweet,tw1})
    GenServer.cast(clientID,{:tweet,tw2})
    GenServer.cast(clientID,{:tweet,tw3})
    :timer.sleep(100)
    livefeed = GenServer.call(liveFollower,{:liveFeed})
    # IO.inspect(livefeed)
    assert length(livefeed) == 3
  end

  test "User tweets offline followers" do
    # 2 users are created where the followers of user are inactive
    # the inactive user doesn't receives the tweet in his live feed
    # the user receives the tweet after logging in
    # Test cases passed
    users = ["user17","user18"]
    Enum.each(users, fn(x) -> {:ok,clientId} = TwitterClient.start_link(x)
                                GenServer.call(clientId,{:registerUser,x,"password"})
                                GenServer.call(clientId, {:loginUser, x, "password"})
                              end)
    clientPid = elem(hd(Registry.lookup(:twitterRegistry, "user17")),0)
    userFollower = elem(hd(Registry.lookup(:twitterRegistry, "user18")),0)
    GenServer.cast(userFollower,{:subscribe, "user17"})
    :timer.sleep(100)
    GenServer.call(userFollower, {:logoutUser})
    userTweet = "user 17 tweet"
    GenServer.cast(clientPid,{:tweet,userTweet})
    :timer.sleep(100)
    whenoffline = GenServer.call(userFollower,{:liveFeed})
    GenServer.call(userFollower, {:loginUser, "user18", "password"})
    whenonline = GenServer.call(userFollower,{:liveFeed})
    assert length(whenoffline) == 0 and length(whenonline) == 1
  end

  test "Retweet User" do
    # 3 users are created 
    # one user(user20) retweets tweet of another user(user19)
    # the user following user20 (user21) receives this tweet in his feed

    users = ["user19","user20","user21"]
    tweetMsg1 = "Tweet1"
    tweetMsg2 = "Tweet2"
    Enum.each(users, fn(x) -> {:ok,clientId} = TwitterClient.start_link(x)
                                GenServer.call(clientId,{:registerUser,x,"password"})
                                GenServer.call(clientId, {:loginUser, x, "password"})
                              end)
    user1pid =  elem(hd(Registry.lookup(:twitterRegistry, "user19")),0)
    user2pid = elem(hd(Registry.lookup(:twitterRegistry, "user20")),0)
    user3pid = elem(hd(Registry.lookup(:twitterRegistry, "user21")),0)
    GenServer.cast(user2pid,{:subscribe, "user19"})
    GenServer.cast(user3pid,{:subscribe, "user20"})
    :timer.sleep(100)
    GenServer.cast(user1pid,{:tweet,tweetMsg1})
    GenServer.cast(user1pid,{:tweet,tweetMsg2})
    :timer.sleep(100)

    [_,retweetMsg] = GenServer.call(user2pid,{:liveFeed})|>Enum.random()
    GenServer.cast(user2pid,{:retweet,retweetMsg})

    feed = GenServer.call(user3pid,{:liveFeed})
    assert length(feed) == 1
  end

end
