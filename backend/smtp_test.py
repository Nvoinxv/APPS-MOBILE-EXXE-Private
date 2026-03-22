import smtplib

email = "edwardfarrel79@gmail.com"
recevier_email = "edwardfarrel79@gmail.com"

subject = input("SUBJECT: ")
message = input("Massage: ")

text = f"Subject: {subject}\n\n{message}"

server = smtplib.SMTP("smtp.gmail.com", 587)
server.starttls()

server.login(email, "gnpqtsetqveddvog")
server.sendmail(email, recevier_email, text)

print("Berhasil semua ke kirim!")