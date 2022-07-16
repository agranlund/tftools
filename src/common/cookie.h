#ifndef _COOKIE_H_
#define _COOKIE_H_

#include "sys.h"
bool cookieSet(uint32 name, uint32 value);
bool cookieGet(uint32 name, uint32* value);

#endif // _COOKIE_H_
