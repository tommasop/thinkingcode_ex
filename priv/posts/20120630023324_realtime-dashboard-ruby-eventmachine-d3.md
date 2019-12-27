{
  "title": "RealTime dashboard: ruby, eventmachine and d3.js",
  "slug": "realtime-dashboard-ruby-eventmachine-d3",
  "datetime": "2012-06-30T02:33:24.939105Z"
}
---
We need to build a dashboard for a field veichle through which we collect different street data.
We have two lasers used to monitor the status of pavimentation and three accelerometers to monitor that data acquisition be consistent and without spikes.
---
We need to build a dashboard for a field veichle through which we collect different street data.

We have two lasers used to monitor the status of pavimentation and three accelerometers to monitor that data acquisition be consistent and without spikes.

We have a GPS to georeference all the collected data and a video camera to actually see the road and be able to log the presence of different kind of elements on the road graph.

Finally we have an odometer to get actual vehicle speed.

All these data are collected each 200ms.

Data are collected in different ways:

  * lasers and accelerometers values are written on a delimited txt file
  * gps data are collected directly with its sdk through USB 
  * the camera takes 10 pictures/s which are written in a folder

**I will focus here on lasers and accelerometers values which are all saved in a semicolon delimited file.**

Data are collected through file modification/creation and this is the reason behind my first architectural choice:

> let the filesystem trigger change events in the dashboard 

This is the fastest way to react to data changes since nothing can be more responsive than the filesystem itself to changes happening in its domain.

Since I use ruby I can easily hook into filesystem events with these libraries:

  * for OSX rb-fsevents
  * for Linux rb-inotify
  * for Windows win32-changenotify

Then I needed a way to communicate real time with my web frontend.  
I opted for eventmachine (because it's ruby!) and web sockets.

**UPDATE**

**eventmachine-tail** is not working on Windows because it leverages the eventmachine FileWatch class which actually is not compatible with Windows.

Furthermore **win32-changenotify** is not the good choice for NTFS systems, you should use **win32-changejournal** which is not installing on my Windows 7 machine [see issue here][1].

So I changed approach and am now using [ruby-filewatch][2] to tail my windows file (and OSX/Linux/Solaris) instead of eventmachine-tail.

<strike>This brought about the natural choice of [eventmachine-tail][3] for file tailing.</strike>

For the websocket there is [em-websocket][4].

So here is the bare minimum for my websocket tail server:



The core server creates a channel (embryonic em pub sub) and a web socket server on port 8080.

Every connection to the web socket subscribes to the channel which is a dual synchronous communication way between server and all connected clients all in few lines of code.

Now that the server is working let's think about the client.

The client here will be a browser connecting to the web socket server through javascript.

But you know javascript is so unrubyish I opted for a coffeescript object to manage the websocket connections. Here it is:



As you might have noticed we need jQuery.

So to put everything together you need to:

  1. Start the eventmachine ruby server
  2. Start a webpage which includes the WSConnector class
  3. Start adding semicolon delimited data to the tailed file

Point two needs further elaboration because you need to setup a simple rack application to compile coffescript and eventually scss and bundle all js and css into two files.

I'll deal about this aspect in another post.

The final bare html page will be something along these lines:



As you can see I'm using [Rickshaw][5] which is a tool built on d3.js especially crafted for interactive time series line graphs.

In tv var I specify the time interval which for my project is 200 milliseconds. I then instantiate an svg (d3.js) area of 600x200 pixels.

Another interesting thing is the **maxDataPoints** option which tells to Rickshaw to keep a maximum of 100 values at a time.

The two data_values I'm pushing into Rickshaw are the ones you can find in the **WSConnector onmessage** method.

 [1]: https://github.com/djberg96/win32-changejournal/issues/3
 [2]: https://github.com/jordansissel/ruby-filewatch
 [3]: https://github.com/jordansissel/eventmachine-tail
 [4]: https://github.com/igrigorik/em-websocket
 [5]: http://code.shutterstock.com/rickshaw/
