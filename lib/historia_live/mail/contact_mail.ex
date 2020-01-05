defmodule Mail.ContactMail do
  import Bamboo.Email

  def contact_email(email, name, subject, content) do
    base_email()
    |> subject(subject)
    |> text_body(contact_mail_body(email, name, content))
  end

  defp base_email() do
    new_email()
    |> from("tommasop@thinkingco.de")
    |> to("tommasop@thinkingco.de")
  end

  defp contact_mail_body(email, name, content) do
    """
    A new contact from thinkingco.de website.

    From: #{name}

    Email: #{email}

    Content: #{content}
    """
  end
end
