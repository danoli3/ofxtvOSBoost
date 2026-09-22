#include <ofxtvOSBoostBridge.h>

#include <iostream>

int main()
{
    if (!ofxtvOSBoostRunLinkTest()) {
        return 1;
    }

    std::cout << "Boost " << ofxtvOSBoostVersion()
              << " linked through a Swift package binary target\n";
    return 0;
}
