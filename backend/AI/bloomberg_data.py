import blpapi

def open_service(session, service_name):
    """Open a Bloomberg service."""
    if not session.openService(service_name):
        print(f"Failed to open {service_name} service")
        return None
    return session.getService(service_name)

# 1. Session options
options = blpapi.SessionOptions()
options.setServerHost("localhost")
options.setServerPort(8194)

# 2. Create session
session = blpapi.Session(options)

# 3. Start session
if not session.start():
    print("Failed to start session")
    exit()

# 4. Open reference data service
refdata_service = open_service(session, "//blp/refdata")
if refdata_service is None:
    session.stop()
    exit()

print("Reference data service opened successfully")
