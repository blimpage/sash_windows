require "sendgrid-ruby"
include SendGrid

def send_mail(html_content:)
  from = SendGrid::Email.new(email: ENV["MORPH_NOTIFICATION_EMAIL_ADDRESS"])
  to = SendGrid::Email.new(email: ENV["MORPH_NOTIFICATION_EMAIL_ADDRESS"])
  subject = "New sash windows!"
  content = SendGrid::Content.new(type: "text/html", value: html_content)
  mail = SendGrid::Mail.new(from, subject, to, content)

  puts "  Sending email notification..."
  sendgrid_agent = SendGrid::API.new(api_key: ENV["MORPH_SENDGRID_API_KEY"])
  response = sendgrid_agent.client.mail._("send").post(request_body: mail.to_json)

  success = response.status_code[0] == "2"

  if success
    puts "  Email notification sent!"
  else
    puts "  Something went wrong while sending email. Response:"
    puts response.inspect
  end
end
