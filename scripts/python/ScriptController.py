import subprocess
import os
import time
import threading
import signal

class ScriptController:
    def __init__(self, script_path, script_name):
        self.script_path = script_path  # 脚本路径作为参数传入
        self.script_name = script_name
        self.process = None

    def start(self, args=None):
        """
        启动脚本
        args: 可选的命令行参数列表
        """
        try:
            command = ['bash', f'./{self.script_name}']
            if args:
                command.extend(args)  # 添加额外的命令行参数
                
            self.process = subprocess.Popen(
                command, 
                cwd=self.script_path  # 使用传入的路径
            )
            print(f"{self.script_name} 启动，PID: {self.process.pid}")
        except Exception as e:
            print(f"启动 {self.script_name} 失败: {e}")

    def is_running(self):
        """检查脚本是否在运行"""
        if self.process:
            return self.process.poll() is None
        return False

    def stop(self):
        """停止脚本"""
        if self.process:
            print(f"正在停止 {self.script_name}...")
            os.kill(self.process.pid, signal.SIGINT)  # 发送SIGINT信号，模拟Ctrl+C
            self.process.wait()  # 等待进程结束
            print(f"{self.script_name} 已停止")
            self.process = None

# def monitor_input(vins_controller, bag_controller):
#     while True:
#         user_input = input("输入 1 开始 VINS Fusion，输入 q 退出：")
#         if user_input == '1':
#             vins_controller.start()
#             time.sleep(2)  # 等待2秒
#             bag_controller.start()
#         elif user_input == 'q':
#             print("正在退出...")
#             bag_controller.stop()
#             vins_controller.stop()
#             break

# if __name__ == "__main__":
#     vins_controller = ScriptController('vinsfusion.sh')
#     bag_controller = ScriptController('bag.sh')

#     # 启动输入监控线程
#     input_thread = threading.Thread(target=monitor_input, args=(vins_controller, bag_controller))
#     input_thread.start()

#     # 等待输入线程结束
#     input_thread.join()
#     print("程序已结束")
