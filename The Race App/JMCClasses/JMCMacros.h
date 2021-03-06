/**
   Copyright 2011 Atlassian Software

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
**/
//
//  JMCMacros.h
//  JIRA_Connect
//
//  Created by Stefan Saasen on 01.06.11.
//  Copyright 2011 Atlassian. All rights reserved.
//

#define JMCLocalizedString(key, comment) \
    [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:@"JMCLocalizable"]
