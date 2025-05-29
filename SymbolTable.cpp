#include <iostream>
#include <cstring>
#include <fstream>
#include <sstream>

using namespace std;

const int MAX_TOKENS = 100;
const int MAX_TOKEN_LENGTH = 100;

typedef unsigned int  (*HashFuncType)(const std::string &);

struct HashFunctionEntry
{
    const char *name;
    HashFuncType func;
};

unsigned int SDBMHash(const std::string &str)
{
    unsigned int hash = 0;
    unsigned int len = str.length();;
    for(unsigned int i = 0;i<len;i++)
    {

        hash = (str[i]) + (hash << 6) + (hash << 16) - hash;
    }

    return hash;
}


unsigned int hashString(const std::string &str)
{
    unsigned long hash = 5381;
    for (char c : str)
        hash = ((hash << 5) + hash) + c;
    return hash;
}

unsigned int SimpleSumHash(const std::string &str)
{
    int sum = 0;
    for (char c : str)
        sum += int(c);
    return sum;
}

unsigned int Seed_Hash(const std::string &str)
{
    int seed = 131;
    unsigned long hash = 0;
    for (char c : str)
        hash = (hash * seed) + c;
    return hash;
}

HashFunctionEntry availableFunctions[] = {
    {"SDBM", SDBMHash},
    {"SimpleSumHash", SimpleSumHash},
    {"hashString", hashString},
    {"Seed", Seed_Hash}};
const int TOTAL_FUNCTIONS = 4;

class SymbolInfo
{
private:
    string name;
    string type;
    SymbolInfo *next;

public:
    SymbolInfo(string name, string type) : name(name), type(type), next(nullptr) {}

    SymbolInfo(string name, string type, SymbolInfo *next) : name(name), type(type), next(next) {}

    string getName()
    {
        return name;
    }

    string getType()
    {
        return type;
    }

    SymbolInfo *getNext()
    {
        return next;
    }

    void setNext(SymbolInfo *next)
    {
        this->next = next;
    }

    void print_FunctionType()
    {
        char copy[1024];
        strncpy(copy, type.c_str(), 1023);
        copy[1023] = '\0';

        char *token = strtok(copy, " ");
        token = strtok(nullptr, " ");
        cout << "<";
        cout << name << ",FUNCTION," << token << "<==(";

        bool first = true;
        while ((token = strtok(nullptr, " ")) != nullptr)
        {
            if (!first)
                cout << ",";
            cout << token;
            first = false;
        }

        cout << ")> ";
    }

    void print_Structype()
    {
        cout << "<" << name << "," << type.substr(0, type.find(' ')) << ",{";

        string fieldStr = type.substr(type.find(' ') + 1);
        char fieldTokens[50][50];
        int count = 0;

        char temp[1000];
        strncpy(temp, fieldStr.c_str(), 999);
        temp[999] = '\0';

        char *tok = strtok(temp, " ");
        while (tok != nullptr && count < 50)
        {
            strncpy(fieldTokens[count], tok, 49);
            fieldTokens[count][49] = '\0';
            count++;
            tok = strtok(nullptr, " ");
        }

        for (int i = 0; i < count; i += 2)
        {
            cout << "(" << fieldTokens[i] << ",";
            if (i + 1 < count)
                cout << fieldTokens[i + 1];
            cout << ")";
            if (i + 2 < count)
                cout << ",";
        }

        cout << "}> ";
    }

    void printSymbol(FILE* out)
    {
        if (type.substr(0, 8) == "FUNCTION")
        {
            print_FunctionType();
        }
        else if (type.substr(0, 6) == "STRUCT" || type.substr(0, 5) == "UNION")
        {
            print_Structype();
        }
        //
        else{
            cout << "< " << name << " : " << type << " > ";
            fprintf(out, "< %s : %s >", name.c_str(), type.c_str());

        }
    }

    ~SymbolInfo()
    {
        // The ScopeTable destructor will handle the chain deletion
    }
};

class ScopeTable
{
    ScopeTable *parent_scope;
    int scopeTableNumber;
    int buckets;
    SymbolInfo **symbols;
    int children;
    HashFuncType hashFunction;
    int collision_count;
    string id;

public:
    ScopeTable(int n, int scopeTableNumber, HashFuncType func) : parent_scope(nullptr), scopeTableNumber(scopeTableNumber), buckets(n),
                                                                 children(0), hashFunction(func), collision_count(0)
    {
        symbols = new SymbolInfo *[buckets];
        for (int i = 0; i < buckets; i++)
        {
            symbols[i] = nullptr;
        }
    }

    void setID(string parentID, int prevSerial)
    {
        if (parentID != "")
            id = parentID + "." + to_string(prevSerial + 1);
        else
            id = to_string(prevSerial + 1);
        if (parent_scope != nullptr)
            parent_scope->increaseChild();
    }
    void setParentScope(ScopeTable *parent)
    {
        this->parent_scope = parent;
        if (parent == nullptr)
        {
            setID("", 0);
        }
        else
        {
            setID(parent_scope->getID(), parent_scope->getChildren());
        }
    }
    string getID()
    {
        return id;
    }

    void increaseChild()
    {
        children++;
    }

    ScopeTable *getParentScope()
    {
        return parent_scope;
    }

    int getScopeTableNumber()
    {
        return scopeTableNumber;
    }

    void setScopeTableNumber(int n)
    {
        this->scopeTableNumber = n;
    }

    int getChildren()
    {
        return children;
    }

    unsigned int  HashFunction(const std::string &str)
    {
        return hashFunction(str) % buckets;
    }

    bool Insert(SymbolInfo *symbol, int scopeCounter,FILE* out)
    {
        int bucket_position = 0, list_position = 1;
        string name = symbol->getName();
        long long arr_index = HashFunction(name);
        if (arr_index < 0)
        {
            arr_index = arr_index * (-1);
        }
        if (symbols[arr_index] == nullptr)
        {
            symbols[arr_index] = symbol;
            cout << '\t';
            //cout << "Inserted in ScopeTable# " << scopeCounter << " at position " << arr_index + 1 << ", " << list_position << endl;
            cout << "Inserted in ScopeTable# " << getID() << " at position " << arr_index + 1 << ", " << list_position << endl;
            
            return true;
        }
        else
        {
            SymbolInfo *symbol1 = symbols[arr_index];
            SymbolInfo *prev = nullptr;

            while (symbol1 != nullptr)
            {
                if (symbol->getName() == symbol1->getName())
                {
                    cout << '\t';
                    fprintf(out, "< %s : %s > already exists in ScopeTable# %s at position %llu, %d\n", symbol->getName().c_str(),symbol->getType().c_str(), this->getID().c_str(), arr_index , list_position-1);
                    cout << "'" << symbol->getName() << "' already exists in the current ScopeTable" << endl;
                    delete symbol;
                    return false;
                }
                prev = symbol1;
                symbol1 = symbol1->getNext();
                list_position++;
            }

            // Insert at the end of the chain
            collision_count++;
            prev->setNext(symbol);
            cout << '\t';
            cout << "Inserted in ScopeTable# " << getID()  << " at position " << arr_index  +1<< ", " << list_position << endl;
            return true;
        }
    }

    SymbolInfo *LookUp(const string &symbolName)
    {
        long long arr_index = HashFunction(symbolName);
        int list_position = 1;
        if (symbols[arr_index] == nullptr)
        {
            return nullptr;
        }

        SymbolInfo *temp = symbols[arr_index];
        while (temp != nullptr)
        {
            if (temp->getName() == symbolName)
            {
                cout << '\t';
                cout << "'" << symbolName << "'" << " found in ScopeTable# " << getID()  << " at position " << arr_index + 1 << ", " << list_position << endl;
                return temp;
            }
            list_position++;
            temp = temp->getNext();
        }
        return nullptr;
    }

    SymbolInfo *LookUp2(const string &symbolName)
    {
        long long arr_index = HashFunction(symbolName);
        if (symbols[arr_index] == nullptr)
        {
            return nullptr;
        }

        SymbolInfo *temp = symbols[arr_index];
        while (temp != nullptr)
        {
            if (temp->getName() == symbolName)
            {
                return temp;
            }
            temp = temp->getNext();
        }
        return nullptr;
    }

    bool Delete(const string &symbolName)
    {
        int arr_index = HashFunction(symbolName);
        int list_position = 1;
        if (symbols[arr_index] == nullptr)
        {
            cout << '\t';
            cout << "Not found in the current ScopeTable" << endl;
            return false;
        }

        SymbolInfo *temp = symbols[arr_index];
        SymbolInfo *prev = nullptr;
        while (temp != nullptr)
        {
            if (temp->getName() == symbolName)
            {
                if (prev == nullptr)
                {
                    symbols[arr_index] = temp->getNext();
                }
                else
                {
                    prev->setNext(temp->getNext());
                }
                delete temp;
                cout << '\t';
                cout << "Deleted '" << symbolName << "' from ScopeTable# " << getID() << " at position " << arr_index + 1 << ", " << list_position << endl;
                return true;
            }
            list_position++;
            prev = temp;
            temp = temp->getNext();
        }
        cout << '\t';
        cout << "Not found in the current ScopeTable" << endl;
        return false;
    }

    void Print(FILE* out, int spaceLevel = 1)
    {
        string indent(spaceLevel, '\t');
        fprintf(out, "ScopeTable # %s\n", id.c_str());

        cout << indent << "ScopeTable# " << id << endl;

        for (int i = 0; i < buckets; i++)
        {
            SymbolInfo *temp = symbols[i ];
            if(temp == nullptr)
            {
                continue;

            }
            cout << indent;
            cout << i << "--> ";
            fprintf(out, "%d --> ", i);

            
            while (temp != nullptr)
            {
                temp->printSymbol(out);
                temp = temp->getNext();
            }
            cout << '\n';
            fprintf(out, "\n");

        }
    }

    void set_collision(int count)
    {
        this->collision_count = count;
    }
    int get_collision()
    {
        return collision_count;
    }

    ~ScopeTable()
    {
        for (int i = 0; i < buckets; i++)
        {
            SymbolInfo *current = symbols[i];
            while (current != nullptr)
            {
                SymbolInfo *next = current->getNext();
                delete current;
                current = next;
            }
            symbols[i] = nullptr;
        }
        delete[] symbols;
        symbols = nullptr;
        cout << '\t';
        cout << "ScopeTable# " << getID() << " removed" << endl;
    }
};

class SymbolTable
{
    ScopeTable *currentScopeTable;
    int n;
    int scopeCounter;
    HashFuncType selectedFunction;

public:
    SymbolTable(int num, int scopeCounter, HashFuncType selectedFunction) : n(num), scopeCounter(scopeCounter), selectedFunction(selectedFunction)
    {
        currentScopeTable = new ScopeTable(num, scopeCounter, selectedFunction);
        currentScopeTable->setParentScope(nullptr);
        // cout << "\tScopeTable# " << scopeCounter << " created" << endl;
    }

    void Enter_Scope(ScopeTable *scopeTable)
    {
        scopeTable->setParentScope(currentScopeTable);
        currentScopeTable = scopeTable;
    }

    void Exit_Scope()
    {
        if (currentScopeTable == nullptr || currentScopeTable->getParentScope() == nullptr)
        {
            cout << '\t';
            cout << "Cannot exit from the root scope table" << endl;
            return;
        }
        ScopeTable *temp = currentScopeTable;
        int scopeNumber = temp->getScopeTableNumber();
        currentScopeTable = currentScopeTable->getParentScope();
        // cout << '\t';
        // cout << "ScopeTable# " << scopeNumber << " removed" << endl;
        delete temp;
    }

    bool Insert(SymbolInfo *symbol, int scopeCounter,FILE* out)
    {
        if (currentScopeTable == nullptr)
            return false;
        return currentScopeTable->Insert(symbol, scopeCounter, out);
    }

    bool Remove(const string &name)
    {
        if (currentScopeTable == nullptr)
            return false;
        return currentScopeTable->Delete(name);
    }

    SymbolInfo *LookUp(const string &symbolName)
    {
        ScopeTable *temp_scope = currentScopeTable;
        if (temp_scope == nullptr)
            return nullptr;

        SymbolInfo *temp = temp_scope->LookUp(symbolName);

        while (temp == nullptr)
        {
            temp_scope = temp_scope->getParentScope();
            if (temp_scope == nullptr)
                return nullptr;
            temp = temp_scope->LookUp(symbolName);
        }
        return temp;
    }

    SymbolInfo *LookUp2(const string &symbolName)
    {
        ScopeTable *temp_scope = currentScopeTable;
        if (temp_scope == nullptr)
            return nullptr;

        SymbolInfo *temp = temp_scope->LookUp2(symbolName);

        while (temp == nullptr)
        {
            temp_scope = temp_scope->getParentScope();
            if (temp_scope == nullptr)
                return nullptr;
            temp = temp_scope->LookUp2(symbolName);
        }
        return temp;
    }

    void Print_current_scope_table(FILE* out)
    {
        currentScopeTable->Print(out,1);
    }

    void PrintAllScopeTables(FILE* out)
    {
        ScopeTable *temp = currentScopeTable;
        int spaceLevel = 1;
        while (temp != nullptr)
        {
            temp->Print(out, spaceLevel);
            temp = temp->getParentScope();
            spaceLevel++;
        }
    }

    ScopeTable *getCurrentScope()
    {
        return currentScopeTable;
    }

    int getTotalCollision()
    {
        int count = 0;
        ScopeTable *temp = currentScopeTable;
        while (temp != nullptr)
        {
            count += temp->get_collision();
            temp = temp->getParentScope();
        }
        return count;
    }

    ~SymbolTable()
    {
        while (currentScopeTable != nullptr)
        {
            ScopeTable *parent = currentScopeTable->getParentScope();
            delete currentScopeTable;
            currentScopeTable = parent;
        }
    }
};
/*

int main(int argc, char *argv[])
{
    HashFuncType selectedFunction = SDBMHash;
    const char *selectedHashName = "SDBM";
    if (argc < 2)
    {
        cerr << "No input file provided." << endl;
        return 1;
    }

    ifstream inputFile(argv[1]);
    ofstream fout("output.txt");

    if (!inputFile)
    {
        cerr << "Failed to open file: " << argv[1] << endl;
        return 1;
    }
    streambuf *originalCout = cout.rdbuf();
    cout.rdbuf(fout.rdbuf());
    if (argc >= 3)
    {
        for (int i = 0; i < TOTAL_FUNCTIONS; i++)
        {
            if (strcmp(argv[2], availableFunctions[i].name) == 0)
            {
                selectedFunction = availableFunctions[i].func;
                selectedHashName = availableFunctions[i].name;
                break;
            }
        }
    }
    char line[1024];
    int numBuckets;
    if (inputFile.getline(line, sizeof(line)))
    {
        numBuckets = atoi(line);
        cout << "\tScopeTable# 1 created" << endl;
    }

    int commandCounter = 0;
    int scopeCounter = 1;
    int total_scope = 1;
    int total_collision = 0;

    SymbolTable *symbolTable = new SymbolTable(numBuckets, scopeCounter, selectedFunction);

    while (inputFile.getline(line, 1024))
    {
        commandCounter++;
        cout << "Cmd " << commandCounter << ": " << line << endl;

        char tokens[MAX_TOKENS][MAX_TOKEN_LENGTH];
        int tokenCount = 0;
        char *token = strtok(line, " ");

        while (token != nullptr && tokenCount < MAX_TOKENS)
        {
            strncpy(tokens[tokenCount], token, MAX_TOKEN_LENGTH - 1);
            tokens[tokenCount][MAX_TOKEN_LENGTH - 1] = '\0';
            tokenCount++;
            token = strtok(nullptr, " ");
        }

        if (strcmp(tokens[0], "I") == 0)
        {

            string name = tokens[1];
            string typeCategory = tokens[2];
            if (typeCategory == "FUNCTION")
            {
                if (tokenCount < 4)
                {
                    cout << '\t';
                    cout << "Number of parameters mismatch for the command I" << endl;
                    continue;
                }
            }
            else if (typeCategory == "STRUCT" || typeCategory == "UNION")
            {
                if ((tokenCount - 3) % 2 != 0 || tokenCount < 5) // Need at least one pair
                {
                    cout << '\t';
                    cout << "Number of parameters mismatch for the command I" << endl;
                    continue;
                }
            }

            char typeConcatenated[1024];
            typeConcatenated[0] = '\0';

            for (int i = 2; i < tokenCount; i++)
            {
                strcat(typeConcatenated, tokens[i]);
                if (i != tokenCount - 1)
                {
                    strcat(typeConcatenated, " ");
                }
            }
            SymbolInfo *symbol = new SymbolInfo(name, typeConcatenated);
            ScopeTable *curr = symbolTable->getCurrentScope();
            int n = curr->getScopeTableNumber();
            symbolTable->Insert(symbol, n);
        }
        else if (strcmp(tokens[0], "L") == 0)
        {
            if (tokenCount != 2)
            {
                cout << '\t';
                cout << "Number of parameters mismatch for the command L" << endl;
            }
            else
            {
                string name = tokens[1];
                SymbolInfo *symbol = symbolTable->LookUp(name);
                if (symbol == nullptr)
                {
                    cout << '\t';
                    cout << "'" << name << "'" << " not found in any of the ScopeTables" << endl;
                }
            }
        }
        else if (strcmp(tokens[0], "D") == 0)
        {
            if (tokenCount != 2)
            {
                cout << '\t';
                cout << "Number of parameters mismatch for the command D" << endl;
            }
            else
            {
                string name = tokens[1];
                ScopeTable *curr = symbolTable->getCurrentScope();
                SymbolInfo *to_delete = curr->LookUp2(name);
                if (to_delete == nullptr)
                {
                    cout << '\t';
                    cout << "Not found in the current ScopeTable" << endl;
                }
                else
                {
                    curr->Delete(name);
                }
            }
        }
        else if (strcmp(tokens[0], "P") == 0)
        {
            if (tokenCount != 2)
            {
                cout << '\t';
                cout << "Number of parameters mismatch for the command P" << endl;
            }
            else
            {
                string printAmount = tokens[1];
                if (printAmount == "C")
                {
                    symbolTable->Print_current_scope_table();
                }
                else if (printAmount == "A")
                {
                    symbolTable->PrintAllScopeTables();
                }
                else
                {
                    cout << '\t';
                    cout << "Invalid Command" << endl;
                }
            }
        }
        else if (strcmp(tokens[0], "S") == 0)
        {
            if (tokenCount != 1)
            {
                cout << '\t';
                cout << "Number of parameters mismatch for the command S" << endl;
            }
            else
            {
                total_scope++;
                scopeCounter++;
                ScopeTable *newScope = new ScopeTable(numBuckets, scopeCounter, selectedFunction);
                symbolTable->Enter_Scope(newScope);
                cout << "\tScopeTable# " << newScope->getID() << " created" << endl;
            }
        }
        else if (strcmp(tokens[0], "E") == 0)
        {
            if (tokenCount != 1)
            {
                cout << '\t';
                cout << "Number of parameters mismatch for the command E" << endl;
            }
            else
            {
                total_scope--;
                symbolTable->Exit_Scope();
            }
        }
        else if (strcmp(tokens[0], "Q") == 0)
        {
            if (tokenCount != 1)
            {
                cout << '\t';
                cout << "Number of parameters mismatch for the command Q" << endl;
            }
            else
            {
                total_collision = symbolTable->getTotalCollision();
                delete symbolTable;
                break;
            }
        }
        else
        {
            cout << "Invalid Command" << endl;
        }
    }

    inputFile.close();
    cout.rdbuf(originalCout);
    fout.close();
    return 0;
}*/