---
title: database.sql.driver

date: 2019-07-17

tags: [MySQL, golang]

author: 付辉

---

在事务操作中，要求事务的各个阶段都使用一个`Conn`连接。在连接被关闭之前，还需要执行`rollback`操作。

文章翻译了`Go`源码下`database.sql.driver`的接口规范，具体实现可以查看源码。

```go

// 包driver定义了数据驱动要实现的接口，具体的实现会在包sql中用到。
//
// 更多还是使用包sql中的代码
package driver

import (
	"context"
	"errors"
	"reflect"
)

// Value必须是一个驱动可以处理的值、NamedValueChecker接口能够处理的类型
// 或者下面这些类型的实例
//
//   int64
//   float64
//   bool
//   []byte
//   string
//   time.Time
//
// 如果驱动支持游标，返回值可能也实现Rows接口。举例，当用户
// 执行"select cursor(select * from my_table) from dual"。
// 如果返回的Rows被Close掉了，游标指向的数据也会被Close掉。
type Value interface{}

// NameValue 同时包括name和value
type NamedValue struct {
    // 如果Name不为空，它应该被用于参数标识符，而非序号位置。
	//
	// Name 没有符号前缀
	Name string

	// 参数从1开始的序号位置，并且总是被设置
	Ordinal int

	// Value是参数值
	Value Value
}

// Driver是一个必须被各个数据库driver实现的接口
//
// 数据库驱动可以实现DriverContext来访问上下文，并且只解析一次连接池的名称，
// 而非每个连接都解析一次。
// 
type Driver interface {
    // Open返回数据库的一个新连接，参数name是驱动特定格式的字符串
	//
	// Open也可以返回一个缓存的连接（之前被close掉的），但这样
	// 做其实没必要。sql包为了连接重复使用维护了一个空闲连接池
	//
	// 返回的连接一次只被一个goroutinue中使用
	Open(name string) (Conn, error)
}

// 如果Driver实现了DriverContext接口，那么sql.DB就会调用OpenConnector
// 来获取一个Connector，调用Connector的Conn方法来获取每个需要的连接，
// 以此代替调用Drive的Open方法。这样允许drivers仅解析一次name，同时提供
// 对每个连接上下文的访问
type DriverContext interface {
    // OpenConnector解析name的方式必须跟Driver.Open的方式保持一致
	OpenConnector(name string) (Connector, error)
}

// 一个Connector表示一个固定配置的driver，能够创建任意数量的等效Conn，
// 供多个goroutinue使用
//
// 一个Connector能被传递给sql.OpenDB方法，去允许驱动实现自己的sql.DB。
// 或者通过调用DriverContext的OpenConnector方法，来返回一个Connector，
// 这样允许驱动访问连接的上下文，避免频繁的解析驱动配置。
type Connector interface {
    // Connect返回一个数据库的连接
    // Connect可能返回一个之前缓存的连接（之前被close掉了），但这样去
    // 做其实是没必要的。sql包维护了一个高效重复使用的空闲连接池。
    //
	//
	// 被提供的context.Context参数仅仅被用于创建连接的目的
	//（看net.DialContext),不应该被存储或用于其他别的目的。
	//
	// 返回的连接一次只能被一个goroutine使用
	Connect(context.Context) (Conn, error)

	// Driver返回Connector的底层驱动，在sql.DB中，主要用于维护
	// 驱动的扩展性
	Driver() Driver
}

// ErrSkip 可能被一些可选接口的方法返回，用于在运行时标识该路径无效。
// 包sql应该继续去执行，就当类型没有实现这个接口一样。
// ErrSkip 只有在被明确说明后才会被支持
// 
var ErrSkip = errors.New("driver: skip fast-path; continue as if unimplemented")

// 当驱动给sql包标识一个driver.Conn处于坏的状态时，ErrBadConn应该被返回（
// 比如服务端已经关闭了这个连接），sql包已经使用一个新的连接进行重试
//
// 为了避免重复操作，如果服务端可能已经完成操作的话，ErrBadConn不应该被返回。
// 即使服务端返回了一个错误，你也不应该返回ErrBadConn
var ErrBadConn = errors.New("driver: bad connection")

// Pinger是一个可选的接口，它可能会被Conn实现
// 
// 如果Conn没有实现Pinger接口，那么sql包的DB.Ping和DB.PingContext
// 将会执行检查，是否至少存在一个可用连接
//
// 如果Conn.Ping返回了ErrBadConn，DB.Ping 和 DB.PingContext将会从连接池中
// 将Conn溢出
type Pinger interface {
	Ping(ctx context.Context) error
}

// Execer 是一个可以被Conn实现的，可选的接口
//
// 如果Conn实现了ExecerContext或Excer，
// 包sql下的DB.Exec将首先prepare查询语句，执行然后关闭。
//
// Exec可能返回ErrSkip错误
//
// 弃用：Drivers应该实现ExecerContext接口来替代Execer
type Execer interface {
	Exec(query string, args []Value) (Result, error)
}

// ExecerContext是可以被Conn实现的、可选的接口
//
// 如果Conn并没有实现ExecerContext接口，那sql包的DB.Exec将会向后调用Excer
// 如果Conn也没有实现Execer接口，
// DB.Exec将首先prepare查询，执行语句、然后关闭语句
//
// ExecerContext 可能返回 ErrSkip错误.
//
// ExecerContext必须认真对待context的超时，当context被取消时，需要返回。
// 
type ExecerContext interface {
	ExecContext(ctx context.Context, query string, args []NamedValue) (Result, error)
}

// Queryer 是一个可选的接口，Conn可能会实现它。
//
// 如果Conn既没有实现QueryerContext，也没有实现Queryer
// 那么sql包的DB.Query首先会prepare一个查询语句，然后执行语句，关闭语句
//
// Query可能会返回 ErrSkip错误.
//
// 弃用：Drivers应该实现QueryerContext接口来替代Queryer
type Queryer interface {
	Query(query string, args []Value) (Rows, error)
}

// QueryerContext 是一个可选的接口，Conn可能会实现它
//
// 如果Conn没有实现QueryerContext，那么sql包在执行DB.Query会降级调用Queryer；
// 如果Conn也没有实现Queryer，DB.Query 首先会prepare一个查询语句，然后执行这个语句
// 然后再关闭它
//
// QueryerContext可能会返回 ErrSkip.
//
// QueryerContext必须认真对待context的超时，当context被cancel掉时，需要返回
type QueryerContext interface {
	QueryContext(ctx context.Context, query string, args []NamedValue) (Rows, error)
}

// Conn是一条数据库的连接，它不能在多个goroutine中同时使用。
//
// Conn被假定为是有状态的
type Conn interface {
	// Prepare返回一个准备好的语句，绑定到这个连接上
	Prepare(query string) (Stmt, error)

	// Close会使当前准备好的语句和事物失效，并可能停止它们执行，
	// 将这个连接标记为不再使用
	//
	// 因为sql包维护了一个空闲连接池，仅当前有多余的空闲连接时，
	// 才会调用Close。对于驱动来说，实现自己的连接缓存是不必要的
	Close() error

    // Begin 启动并返回一个新的事务
	//
	// 弃用：驱动应该通过实现ConnBeginTx来替换Begin
	Begin() (Tx, error)
}

// ConnPrepareContext通过使用context，加强了Conn接口
type ConnPrepareContext interface {
	// context被用来对语句做预处理
	// 在语句本身中是不可以存储context的
	PrepareContext(ctx context.Context, query string) (Stmt, error)
}

// IsolationLevel在TxOptions类型中记录事物的隔离级别
//
// 这个类型应该认被为跟sql.IsolationLevel是一致的，以及定义这个类型的其他值。
// 
type IsolationLevel int

// TxOptions 设置事物的选项
//
// 这个类型应该被认为跟sql.TxOptions是一致的
type TxOptions struct {
	Isolation IsolationLevel
	ReadOnly  bool
}

// ConnBeginTx通过context和TxOptions提高了Conn接口
type ConnBeginTx interface {
    // BeginTx启动并返回一个新的事务
    // 如果context被用户取消了，sql包会在丢弃和关闭这个连接之前
    // 执行Tx.Rollback
	//
	// 函数必须检查opts.Isolation，确定是否存在设置的额隔离级别。
	// 如果驱动不支持一个非默认的隔离级别和被设置的级别，或者
	// 存在一个非默认的隔离级别是不支持的，必须返回一个错误
	//
	// 函数也必须检查opts.ReadOnly，如果ReadOnly值为真，
	// 如果支持设置的话，则设置只读事务属性。如果不支持的话，返回error
	// 
	BeginTx(ctx context.Context, opts TxOptions) (Tx, error)
}

// Conn可能会实现SessionResetter接口，用于重置当前连接上的会话状态
// 并将当前连接标识为坏连接
type SessionResetter interface {
	// 当连接在连接池中时，调用ResetSession方法。该连接不会再承载任何查询操作
	// 直接方法返回
	//
	// 如果连接是坏的，方法应该返回driver.ErrBadConn错误，来阻止连接被放回到
	// 连接池。其他别的错误将会被丢弃
	ResetSession(ctx context.Context) error
}

// Result是查询执行的结果
type Result interface {
	// LastInsertId返回数据库自动生成的ID，比如，用主键插入表的操作
	LastInsertId() (int64, error)

	// RowsAffected返回查询影响的行数
	RowsAffected() (int64, error)
}

// Stmt是一个准备好的语句，它被绑定到一个Conn，且不能被多个goroutine并发
// 使用
type Stmt interface {
	// Close关闭这个语句
	//
	// 截止到Go 1.1，如果Stmt在被一些查询使用，Stmt将不会被关闭
	Close() error

	// NumInput返回占位符的个数
	//
	// 如果NumInput返回值大于等于0，sql包会明智的检查调用者的参数个数，
	// 在Exec或Query被调用之前，返回错误给调用者。
	//
	// 如果驱动不知道占位符的个数，NumInput可能会返回-1。在这种情况下，
	// sql包将不会检查Exec和Query的参数个数
	NumInput() int

	// Exec执行一个不返回数据行的查询，比如INSERT或UPDATE
	//
	// 弃用：驱动应实现StmtExecContext来替代
	Exec(args []Value) (Result, error)

	// Query执行一个返回数据行的查询，比如SELECT
	//
	// 弃用：驱动应实现StmtQueryContext来替代
	Query(args []Value) (Rows, error)
}

// StmtExecContext升级了Stmt接口，它提供了一个有context的Exec，
type StmtExecContext interface {
	// ExecContext执行一个不返回数据行的查询，比如INSERT或UPDATE
	//
	// ExecContext必须遵守context超时，当context被取消时，函数需要返回
	ExecContext(ctx context.Context, args []NamedValue) (Result, error)
}

// StmtQueryContext升级了Stmt接口，它提供了一个有context的Query
type StmtQueryContext interface {
    // QueryContext执行一个返回数据行的查询，比如SELECT
	//
	// ExecContext必须遵守context超时，当context被取消时，函数需要返回
	QueryContext(ctx context.Context, args []NamedValue) (Rows, error)
}

// ErrRemoveArgument可能被NamedValueChecker返回，用来指示sql包不要
// 给驱动的query接口传递这个参数。
// 当接收到不是查询参数的特定属性或结构时，返回该错误
var ErrRemoveArgument = errors.New("driver: remove argument from query")

// Conn或Stmt可选择是否要实现NamedValueChecker接口。接口提供给驱动
// 更多的控制，去处理超出Go和数据库允许的默认值类型。
//
// 对于值的检查对象，sql包按如下顺序进行检查。当第一次发现匹配时停止：
// Stmt.NamedValueChecker, Conn.NamedValueChecker, Stmt.ColumnConverter,
// DefaultParameterConverter.
//
// 如果CheckNamedValue返回ErrRemoveArgument错误，那么这个NamedValue将不会
// 被包含在最终的查询参数中。这可能会被用于给查询传递特殊的选项。
//
// 如果ErrSkip错误被返回，则使用列转换器错误检查路径作为参数。
// 驱动可能希望在耗尽自己特殊case后返回ErrSkip
type NamedValueChecker interface {
	// 在传递参数给驱动之前，CheckNamedValue会被调用。
	// 在任何ColumnConverter的地方也会调用CheckNamedValue。
	// CheckNamedValue必须根据驱动的需要做类型校验和转换
	CheckNamedValue(*NamedValue) error
}

// 如果语句知道自己列的类型，并且能够从任何类型转换为驱动的Value，
// 那么Stmt 可以选择性的实现ColumnConverter
// 
// 弃用：驱动应实现NamedValueChecker
type ColumnConverter interface {
	// 根据提供的列序号，ColumnConverter返回一个 ValueConverter。
	// 如果该列是未知的或者不需要被特殊处理，方法返回DefaultValueConverter
	ColumnConverter(idx int) ValueConverter
}

// Rows是一个查询结果的迭代器
type Rows interface {
	// Columns返回列的名字集，它的个数是从slice的长度中推断出来的。
	// 如果不知道特定的列名，应该为该条目返回一个空的字符串
	Columns() []string

	// 关闭行迭代器
	Close() error

	// Next用于把数据集中的下一行填入提供的slice中。该slice的
	// 长度应该跟Columns()的长度一致
	//
	// 当没有数据行时，Next应该返回io.EOF
	// 
	// dest不应被声明在Next之外(应该作为Next的一个成员变量)
	// 关闭Rows时应特别注意，不要修改dest中缓冲区的值
	Next(dest []Value) error
}

// RowsNextResultSet扩展了Rows接口，它提供了一个方式，让驱动向前移动
// 到下一个结果集
type RowsNextResultSet interface {
	Rows

	// 在当前结果集的末尾调用HasNextResultSet，报告当前结果集之后是否还存在
	// 别的结果集
	HasNextResultSet() bool

	// NextResultSet向前移动驱动到下一个结果集，即使当前结果集
	// 仍然存在剩余的数据行
	//
	// 当不再有数据集时，NextResultSet应该返回io.EOF
	NextResultSet() error
}

// RowsColumnTypeScanType可以通过Rows实现，它应该返回可用于扫描的数据类型。
// 比如，数据库的列类型`bigint`应该返回"reflect.TypeOf(int64(0))".
type RowsColumnTypeScanType interface {
	Rows
	ColumnTypeScanType(index int) reflect.Type
}

// RowsColumnTypeDatabaseTypeName可以通过Rows实现。它应该返回不包括字段长度的数据库类型，
// 类型名应该全大写。诸如："VARCHAR", "NVARCHAR", "VARCHAR2", "CHAR", "TEXT",
// "DECIMAL", "SMALLINT", "INT", "BIGINT", "BOOL", "[]BIGINT", "JSONB", "XML",
// "TIMESTAMP".
type RowsColumnTypeDatabaseTypeName interface {
	Rows
	ColumnTypeDatabaseTypeName(index int) string
}

// RowsColumnTypeLength可以通过Rows实现，如果列是可变长度的类型，它应该返回
// 类型的长度。如果列是不可变长度的类型，ok返回false。
// 如果类型长度只受系统限制，则应该返回math.MaxInt64
// 下面是变量类型的返回值示例
//   TEXT          (math.MaxInt64, true)
//   varchar(10)   (10, true)
//   nvarchar(10)  (10, true)
//   decimal       (0, false)
//   int           (0, false)
//   bytea(30)     (30, true)
type RowsColumnTypeLength interface {
	Rows
	ColumnTypeLength(index int) (length int64, ok bool)
}

// RowsColumnTypeNullable可以通过Rows实现。如果指定的列可以为空，则nullable
// 返回true。相反，如果列不能为空，nullable应该返回false。
// 如果不知道该列是否可以为空，ok应该返回false
type RowsColumnTypeNullable interface {
	Rows
	ColumnTypeNullable(index int) (nullable, ok bool)
}

// RowsColumnTypePrecisionScale可以被Rows实现，对于decimal类型，它应该返回
// 精度和小数点右边的范围。如果类型不适用，ok应返回false
// 下面是不同类型的返回值示例：
//   decimal(38, 4)    (38, 4, true)
//   int               (0, 0, false)
//   decimal           (math.MaxInt64, math.MaxInt64, true)
type RowsColumnTypePrecisionScale interface {
	Rows
	ColumnTypePrecisionScale(index int) (precision, scale int64, ok bool)
}

// Tx是一个事务
type Tx interface {
	Commit() error
	Rollback() error
}

// RowsAffected实现了INSERT或UPDATE操作的结果
// 表示被影响的行数
type RowsAffected int64

var _ Result = RowsAffected(0)

func (RowsAffected) LastInsertId() (int64, error) {
	return 0, errors.New("LastInsertId is not supported by this driver")
}

func (v RowsAffected) RowsAffected() (int64, error) {
	return int64(v), nil
}

// ResultNoRows是一个预定义的结果，在一个DDL操作(比如CREATE TABLE)执行成功
// 时返回。调用该类型的LastInsertId和LastInsertId方法会返回错误
var ResultNoRows noRows

type noRows struct{}

var _ Result = noRows{}

func (noRows) LastInsertId() (int64, error) {
	return 0, errors.New("no LastInsertId available after DDL statement")
}

func (noRows) RowsAffected() (int64, error) {
	return 0, errors.New("no RowsAffected available after DDL statement")
}
```