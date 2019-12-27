{
  "title": "Rails 3 is_documentable with activeadmin",
  "slug": "rails-3-is_documentable-with-activeadmin",
  "datetime": "2012-07-11T02:33:24.939105Z"
}
---
I need to add the chance to add as many documents as needed for several models of a Rails 3 app.
Each model is something that can have associated drawings, administrative acts and so forth.
To avoid duplication as far as possible I opted for an acts_as like feature for documents.
---

I need to add the chance to add as many documents as needed for several models of a Rails 3 app.

Each model is something that can have associated drawings, administrative acts and so forth.

To avoid duplication as far as possible I opted for an acts_as like feature for documents.

It will be called acts as documentable.

The acts as coding pattern rely on the [polymorphic association][1] with which a model can belong to more than one other model, on a single association.

Let's see what this means.

Let's imagine we have three models: User, Project and Tasks.

We want each model to be able to store n documents uploaded by a user.

With a polymorphic association we can obtain this result with the following Rails code:



The polymorphic reference in the migration automatically creates two columns:

  * **documentable_id**: the id of the object to which the document will be added
  * **documentable_type**: the class name of the object to which the document will be added

In this way Rails will be able to add n documents to each model which will be documentable.

We thus need a way to extend each model with the Documentable module.

This is achieved extending ActiveRecord::Base and is the **standard** way of structuring a gem extension for ActiveRecord.

Here is the structure:



The documentable.rb file should be saved in the **lib** folder.

In Rails 3 because of the assets pipeline files included in the lib folder are no longer loaded by default.

You both need to explicitly load files in the lib AND require them! I know it sounds strange but it0s the only way I managed to extend ActiveRecord with my Documentable module.

Now I can extend my models with the is_documentable class method and let them be able to have many documents:

Now let's throw in a couple more things:

  * **dragonfly** to upload files
  * **activeadmin** to manage documents

For dragonfly nothing interesting, just follow the [rails 3 quick start guide][2] and use the **file_accessor** instead of the image_accessor.

Something more interesting for activeadmin. Here you can add a nested form for your documents using the wonderful **has_many** form method:



What this code does is simply to add a nested form for documents with buttons to add and remove each document!

If you want some more info on the has_many method [check this page on active_admin][3].

Maybe I'll set up a gem sometime.

 [1]: http://guides.rubyonrails.org/association_basics.html#polymorphic-associations
 [2]: http://markevans.github.com/dragonfly/file.README.html
 [3]: https://github.com/gregbell/active_admin/issues/59
