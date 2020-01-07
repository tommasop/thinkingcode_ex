{
  "title": "Polymorphic attachments for Rails 4 and ActiveAdmin",
  "slug": "polymorphic-attachments-for-rails-4-and-activeadmin",
  "datetime": "2014-01-04T02:33:45.939105Z"
}

---
Following my [2012 post!!!][1] I finally managed to write down a small Rails 4 engine that allows anyone to add multiple files to any model in his rails app.
---

Following my [2012 post!!!][1] I finally managed to write down a small Rails 4 engine that allows anyone to add multiple files to any model in his rails app.

The gem has the highly innovative name of: **AttachIt**.

As the original post also took into account ActiveAdmin I managed to add the same functionalities to ActiveAdmin also.

The gem is thought for use in the show action for your model.

I have a lot of websites with this requirement of handling multiple files for multiple models so I think this must be a fairly common pattern.

I also use [activeadmin][2] quite broadly and find it highly flexible. And it is indeed! Here I use [dropzonejs.com][3] inside activeadmin and also import bootstrap modal and grid to handle the responsive image gallery.

Enjoy: <https://github.com/tommasop/attach_it>

 [1]: http://thinkingco.de/techblog/rails-3-is_documentable-with-activeadmin/
 [2]: https://github.com/activeadmin/activeadmin
 [3]: http://www.dropzonejs.com

