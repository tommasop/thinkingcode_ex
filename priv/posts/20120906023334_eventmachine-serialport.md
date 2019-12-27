{
  "title": "EventMachine & Serialport",
  "slug": "eventmachine-serialport",
  "datetime": "2013-09-06T02:33:24.939105Z"
}
---
I need to communicate with an inertial platform to track GPS data in a dashboard.
As the dashboard is working with EventMachine I decided to use ruby-serialport with EventMachine.
---

I need to communicate with an inertial platform to track GPS data in a dashboard.

As the dashboard is working with EventMachine I decided to use [ruby-serialport][1] with EventMachine.

**UPDATE**

em-serialport is **not working on Windows** furthermore, having a good chat on the irc eventmachine channel, the use of eventmachine pure ruby library is not at all efficient.

First of all you can now install eventmachine version 1.0.0 on Windows.

Then I decided to follow the approach used in [serialport-server][2] to listen to my serialport.

The idea is simple: wrap the serial port connection in a websocket's one.



Now in the main eventmachine reactor I can open a TCP server websocket connection to my Serial Port like this:



It is working very well both on Windows and on OSX.

**THIS IS USELESS PLEASE DON'T USE IT**

<strike>I found out there is a nice [em-serialport][3] gem than can do the job.</strike>

Unfortunately my dashboard will run on a Windows 7 pc.

So here comes the first problem: the actual version of EventMachine (0.12.10) will not compile on windows.

It is a well known issue and you simply will not be able to install it (nor any 0.12 version for what it matters).

There is a solution though and it is to install the version 1.0.0.rc

EventMachine will compile flawlessly and you will once more be a happy programmer.

Unfortunately your happiness will not last because em-serialport requires in its gemspec eventmachine 0.12.10.

So when you install em-serialport on windows it will complain that it cannot install EventMachine.

If you force the gem installation with the --no-dependencies flag it will install but when you require it it will happily blow up.

So you need to change the gemspec file setting the pre version of EventMachine.

Then you need to make another change in em-serialport.rb

They improved the way pure_ruby EventMachine ruby can be loaded and you have to modify it like this:

In the end just build the new gem from the gemspec and install it.

 [1]: https://github.com/hparra/ruby-serialport
 [2]: https://github.com/shokai/serialport-server/blob/master/bin/serialport-server
 [3]: https://github.com/railsbob/em-serialport
